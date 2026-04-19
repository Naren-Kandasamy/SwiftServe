import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:shared/models/alert.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'status_screen.dart';
import 'knowledge_library_screen.dart';
import 'package:shared/venue_config.dart';
import '../services/connectivity_service.dart';
import '../services/ble_service.dart';
import '../services/ble_scanner_service.dart';
import '../services/sms_fallback.dart';
import '../services/offline_knowledge.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  String? _selectedEmergencyType;
  late AnimationController _pulseController;
  final TextEditingController _descController = TextEditingController();
  
  XFile? _attachedImage;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isSubmitting = false;
  double _soundLevel = 0.0;
  
  ConnectivityTier _currentTier = ConnectivityTier.online;
  StreamSubscription<ConnectivityTier>? _tierSubscription;
  String _selectedFloor = VenueConfig.floors.first;
  String _selectedRoom = VenueConfig.roomsForFloor(VenueConfig.floors.first).first;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {'name': 'Fire', 'icon': Icons.local_fire_department, 'color': Colors.orangeAccent},
    {'name': 'Medical', 'icon': Icons.medical_services, 'color': Colors.redAccent},
    {'name': 'Security', 'icon': Icons.security, 'color': Colors.lightBlueAccent},
    {'name': 'Infrastructure', 'icon': Icons.construction, 'color': Colors.brown[400]},
    {'name': 'Other', 'icon': Icons.help_outline, 'color': Colors.grey[400]},
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    ConnectivityService().initialize();
    _tierSubscription = ConnectivityService().tierStream.listen((tier) {
      if (mounted) setState(() => _currentTier = tier);
    });
    
    // Check for local queue items on boot
    _syncLocalQueue();
  }

  Future<void> _syncLocalQueue() async {
    if (_currentTier != ConnectivityTier.online) return;
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('local_alerts') ?? [];
    if (queue.isEmpty) return;

    print('[SosScreen] Syncing ${queue.length} offline alerts to Firebase...');
    final List<String> failed = [];
    for (final jsonStr in queue) {
      try {
        final Map<String, dynamic> alertMap = Map<String, dynamic>.from(jsonDecode(jsonStr));
        final alertId = alertMap['id'] as String;
        final venueId = alertMap['venueId'] as String;
        await FirebaseDatabase.instance
            .ref('venues/$venueId/alerts/$alertId')
            .set(alertMap)
            .timeout(const Duration(seconds: 10));
        print('[SosScreen] Synced offline alert $alertId successfully.');
      } catch (e) {
        print('[SosScreen] Failed to sync alert, keeping in queue: $e');
        failed.add(jsonStr); // Keep failed ones for next attempt
      }
    }
    await prefs.setStringList('local_alerts', failed);
  }

  @override
  void dispose() {
    _tierSubscription?.cancel();
    _pulseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _attachPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 800,
    );
    if (image != null) {
      setState(() {
        _attachedImage = image;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo attached successfully!'), duration: Duration(milliseconds: 1500)),
      );
    }
  }

  Future<void> _showLocationPicker() async {
    String tempFloor = _selectedFloor;
    String tempRoom = _selectedRoom;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
          left: 24, right: 24, top: 24
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final rooms = VenueConfig.roomsForFloor(tempFloor);
            // Reset room if it doesn't exist on the new floor
            if (!rooms.contains(tempRoom)) tempRoom = rooms.first;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Set Your Location', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('This is shared with front desk staff only', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 20),
                // Floor selector
                DropdownButtonFormField<String>(
                  value: tempFloor,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Floor',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: VenueConfig.floors.map((f) => DropdownMenuItem(value: f, child: Text('Floor $f'))).toList(),
                  onChanged: (val) => setModalState(() { 
                    tempFloor = val!;
                    final newRooms = VenueConfig.roomsForFloor(tempFloor);
                    tempRoom = newRooms.first;
                  }),
                ),
                const SizedBox(height: 16),
                // Room selector — auto-refreshes when floor changes
                DropdownButtonFormField<String>(
                  value: tempRoom,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Room / Area',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: VenueConfig.roomsForFloor(tempFloor)
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setModalState(() => tempRoom = val!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedFloor = tempFloor;
                        _selectedRoom = tempRoom;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Future<void> _toggleListen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required.'), backgroundColor: Colors.red)
          );
        }
        return;
      }
      
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _descController.text = val.recognizedWords;
          }),
          onSoundLevelChange: (level) => setState(() {
            _soundLevel = level;
          }),
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.blueGrey[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'CRISISNET',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.menu_book, color: Colors.white70),
                          tooltip: 'Offline Emergency Library',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const KnowledgeLibraryScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Connectivity Badge
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentTier == ConnectivityTier.online 
                          ? Colors.green.withValues(alpha: 0.2)
                          : _currentTier == ConnectivityTier.limited 
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _currentTier == ConnectivityTier.online 
                          ? Colors.green 
                          : _currentTier == ConnectivityTier.limited ? Colors.orange : Colors.red,
                      )
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentTier == ConnectivityTier.online 
                            ? Icons.wifi 
                            : _currentTier == ConnectivityTier.limited ? Icons.wifi_password : Icons.wifi_off,
                          size: 14,
                          color: _currentTier == ConnectivityTier.online 
                            ? Colors.green 
                            : _currentTier == ConnectivityTier.limited ? Colors.orange : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentTier.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _currentTier == ConnectivityTier.online 
                              ? Colors.green 
                              : _currentTier == ConnectivityTier.limited ? Colors.orange : Colors.red,
                          )
                        )
                      ],
                    ),
                  ),
                ),

                // Location Selector Banner
                InkWell(
                  onTap: _showLocationPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Floor $_selectedFloor, Room $_selectedRoom', 
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)
                          ),
                        ),
                        const Text('CHANGE', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'What is your emergency?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _emergencyTypes.map((type) => _buildEmergencyTypeCard(type)).toList(),
                  ),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMicButton(),
                    _buildActionButton(
                      _attachedImage != null ? Icons.check_circle : Icons.camera_alt, 
                      _attachedImage != null ? 'Photo Attached' : 'Attach Photo', 
                      _attachPhoto,
                      color: _attachedImage != null ? Colors.green[700] : Colors.grey[850],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tap to type details (optional)...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 20),
                
                Expanded(
                  flex: 3,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedEmergencyType != null) {
                          _triggerSOS();
                        } else {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select an emergency type first!'),
                              backgroundColor: Colors.orange,
                              duration: Duration(milliseconds: 1500),
                            ),
                          );
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final double scale = _selectedEmergencyType != null 
                              ? 1.0 + (_pulseController.value * 0.05) 
                              : 1.0;
                          final double glow = _selectedEmergencyType != null 
                              ? (_pulseController.value * 15.0) 
                              : 0.0;
                              
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _selectedEmergencyType != null 
                                      ? [Colors.redAccent, Colors.red[900]!] 
                                      : [Colors.grey[800]!, Colors.grey[900]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedEmergencyType != null 
                                        ? Colors.redAccent.withValues(alpha: 0.6) 
                                        : Colors.black54,
                                    blurRadius: 20 + glow,
                                    spreadRadius: 5 + (glow * 0.5),
                                  ),
                                ]
                              ),
                              child: Center(
                                child: _isSubmitting 
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Colors.white),
                                        SizedBox(height: 12),
                                        Text('SENDING...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 50, color: Colors.white),
                                        SizedBox(height: 8),
                                        Text(
                                          'SOS',
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontSize: 32, 
                                            fontWeight: FontWeight.w900, 
                                            letterSpacing: 2
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                const Text(
                  'Hold connection for real-time status after triggering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeCard(Map<String, dynamic> type) {
    bool isSelected = _selectedEmergencyType == type['name'];
    Color typeColor = type['color'] as Color;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedEmergencyType = type['name'];
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: (MediaQuery.of(context).size.width * 0.28).clamp(80.0, 110.0),
          height: 105,
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(
                    colors: [
                      typeColor.withValues(alpha: 0.4), 
                      typeColor.withValues(alpha: 0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey[850]!, Colors.grey[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? typeColor.withValues(alpha: 0.8) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected 
                ? [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ] 
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  type['icon'], 
                  color: isSelected ? typeColor : Colors.white54, 
                  size: 32
                ),
              ),
              const SizedBox(height: 10),
              Text(
                type['name'],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.grey[850],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildMicButton() {
    // Normal scale is 1.0. When listening, soundLevel (usually between -50 and 50) scales the button.
    // For normalization, assuming level goes up to 10 in standard conversation.
    final glowScale = _isListening ? 1.0 + (_soundLevel.clamp(0.0, 50.0) / 100.0) : 1.0;
    
    return GestureDetector(
      onTap: _toggleListen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _isListening 
                ? Colors.redAccent.withValues(alpha: 0.5 * glowScale) 
                : Colors.black.withValues(alpha: 0.2),
              blurRadius: _isListening ? 15 * glowScale : 5,
              spreadRadius: _isListening ? 3 * glowScale : 0,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Badge(
           isLabelVisible: _isListening,
           label: const Text('REC', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
           backgroundColor: Colors.red,
           child: Transform.scale(
             scale: glowScale,
             child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red[900] : Colors.grey[850],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              onPressed: _toggleListen,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 18),
              label: Text(_isListening ? 'Listening' : 'Voice Input', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
           ),
        ),
      ),
    );
  }

  Future<void> _triggerSOS() async {
    if (_isSubmitting) return;

    // Strict Location Privacy Gate (GDPR compliant)
    bool? consentGiven = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: Colors.blueAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Location Tracking Consent', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: const Text(
          'Your location (Room/Floor) will be shared with front desk staff exclusively to dispatch emergency responders.\n\nThere is no background tracking. The location pin is temporary and is destroyed the moment the incident closes.\n\nDo you consent to sharing your location?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I AGREE - SEND SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (consentGiven != true) {
      return; // Fallback to safe zero-action state if they reject
    }

    // Request permissions for BLE Mesh / location tracking (Not supported on bare Web fallback)
    if (!kIsWeb) {
      await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();
    }

    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    try {
      final String alertId = const Uuid().v4();
      
      EmergencyType parsedType = EmergencyType.values.firstWhere(
        (e) => e.name.toLowerCase() == _selectedEmergencyType?.toLowerCase(),
        orElse: () => EmergencyType.other,
      );

      final alert = Alert(
        id: alertId,
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'offline_user', // True Auth UUID
        venueId: 'mockVenue123',
        roomNumber: _selectedRoom,
        floor: int.tryParse(_selectedFloor) ?? 1,
        description: _descController.text,
        imageUrl: _attachedImage != null ? 'pending_upload' : null, // Written immediately — image patches in below
        type: parsedType,
        location: const GeoPoint(0.0, 0.0), // TODO: GPS
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: AlertStatus.pending,
        assignedTo: [],
      );

      if (_currentTier == ConnectivityTier.online) {
        // Using .timeout so it doesn't hang forever on fake credentials
        await FirebaseDatabase.instance
            .ref()
            .child('venues/${alert.venueId}/alerts/$alertId')
            .set(alert.toMap())
            .timeout(const Duration(seconds: 15));

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => StatusScreen(alertId: alertId),
          ),
        );

        // Background image upload — fires AFTER navigation so guest isn't blocked
        // TriageService polls up to 6s for imageUrl to appear before calling Gemini
        if (_attachedImage != null) {
          Future(() async {
            try {
              final bytes = await _attachedImage!.readAsBytes();
              final base64String = base64Encode(bytes);
              final String dataUrl = 'data:image/jpeg;base64,$base64String';
              
              await FirebaseDatabase.instance
                  .ref('venues/${alert.venueId}/alerts/$alertId')
                  .update({'imageUrl': dataUrl});
              debugPrint('[SosScreen] Base64 Image converted + patched into alert: $alertId');
            } catch (e) {
              debugPrint('[SosScreen] Background base64 image encoding failed (non-fatal): $e');
            }
          });
        }
      } else {
        // TIER 2-4 DEGRADATION FLOW
        print('[SosScreen] Device Offline/Limited. Triggering Fallback Protocol...');
        
        // 1. Save to Local Queue
        final prefs = await SharedPreferences.getInstance();
        final queue = prefs.getStringList('local_alerts') ?? [];
        queue.add(jsonEncode(alert.toMap()));
        await prefs.setStringList('local_alerts', queue);
        
        // 2. Start BLE Mesh Peripheral (advertise alert as beacon)
        await BleService().startMeshAdvertising(alert);
        
        // Also start scanning — this device becomes a relay node in the mesh
        // It will pick up and retransmit beacons from other nearby devices
        BleScannerService().startScanning(venueId: alert.venueId);
        
        // 3. SMS Fallback Prompt
        bool? useSms = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Connection Lost', style: TextStyle(color: Colors.orangeAccent)),
            content: const Text(
              'We could not reach the server. We are broadcasting your alert locally via Bluetooth.\n\nWould you also like to send an emergency SMS to the staff?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO, JUST BLE')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('SEND SMS')
              ),
            ],
          )
        );
        
        if (useSms == true) {
          await SmsFallbackService.sendSmsAlert(alert);
        }
        
        // 4. Open Offline Knowledge Base regardless of SMS choice
        if (mounted) {
           OfflineKnowledgeService.showKnowledgeScreen(context, parsedType);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SOS: Time out or config missing. Check your credentials.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _listenForAITriage(String alertId, String venueId) {
    FirebaseDatabase.instance
        .ref('venues/$venueId/alerts/$alertId')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) return;
      
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (data['status'] == 'triaged' && data['safetyInstructions'] != null) {
        _showSafetyInstructionsModal(data['safetyInstructions']);
      }
    });
  }

  void _showSafetyInstructionsModal(String instructions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.redAccent, width: 3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'CRITICAL INSTRUCTIONS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Sent by Command Center AI',
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                instructions,
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('I UNDERSTAND', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
