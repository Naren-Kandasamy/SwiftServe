import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:shared/models/alert.dart';
import 'package:flutter/services.dart';

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _attachPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _attachedImage = image;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo attached successfully!'), duration: Duration(milliseconds: 1500)),
      );
    }
  }

  Future<void> _toggleListen() async {
    if (!_isListening) {
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'CRISISNET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                    ),
                  ),
                ),
                
                const Text(
                  'What is your emergency?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 30),
                
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
          width: MediaQuery.of(context).size.width * 0.28,
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
        userId: 'mockUser99', // TODO: Firebase Auth UID
        venueId: 'mockVenue123',
        roomNumber: '101',    // TODO: Dynamic from check-in
        floor: 1,
        description: _descController.text,
        imageUrl: _attachedImage?.path, // Pending actual Storage upload
        type: parsedType,
        location: const GeoPoint(0.0, 0.0), // TODO: GPS
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: AlertStatus.pending,
        assignedTo: [],
      );

      // Using .timeout so it doesn't hang forever on fake credentials
      await FirebaseDatabase.instance
          .ref()
          .child('venues/${alert.venueId}/alerts/$alertId')
          .set(alert.toMap())
          .timeout(const Duration(seconds: 15));

      // Hook up the live AI listener to catch the instructions
      _listenForAITriage(alertId, alert.venueId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('SOS Dispatched Successfully!', style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ),
      );
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
