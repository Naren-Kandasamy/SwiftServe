import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/models/alert.dart';
import 'package:intl/intl.dart';
import 'status_screen.dart';

class RejoinScreen extends StatefulWidget {
  const RejoinScreen({super.key});

  @override
  State<RejoinScreen> createState() => _RejoinScreenState();
}

class _RejoinScreenState extends State<RejoinScreen> {
  final _tokenController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;
  List<Alert> _foundAlerts = [];

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _findAlert() async {
    final token = _tokenController.text.trim().toUpperCase();
    if (token.length != 6) {
      setState(() => _errorMessage = 'Please enter your full 6-character room code.');
      return;
    }
    setState(() { 
      _isSearching = true; 
      _errorMessage = null; 
      _foundAlerts = [];
    });

    try {
      debugPrint('[RejoinScreen] Searching for token: "$token"');
      final alertsSnap = await FirebaseDatabase.instance
          .ref('venues/mockVenue123/alerts')
          .get()
          .timeout(const Duration(seconds: 5));

      if (!alertsSnap.exists) {
        debugPrint('[RejoinScreen] No alerts node found in Firebase.');
        setState(() { _isSearching = false; _errorMessage = 'No active emergency found for this room code.'; });
        return;
      }

      final List<Alert> activeAlerts = [];
      final alertsMap = Map<String, dynamic>.from(alertsSnap.value as Map);
      debugPrint('[RejoinScreen] Found ${alertsMap.length} total alerts in Firebase.');

      alertsMap.forEach((alertId, alertData) {
        try {
          final alertMap = Map<dynamic, dynamic>.from(alertData as Map);
          final String? alertRoomKey = alertMap['roomKey']?.toString();
          final String? alertStatus = alertMap['status']?.toString();
          
          debugPrint('[RejoinScreen] Checking alert $alertId -> roomKey: "$alertRoomKey", status: "$alertStatus"');
          
          // Only check roomKey manually first to bypass parsing issues
          if (alertRoomKey == token && alertStatus != 'resolved') {
            debugPrint('[RejoinScreen] Match found! Parsing alert $alertId...');
            final alert = Alert.fromMap(alertMap);
            activeAlerts.add(alert);
          }
        } catch (e) {
          debugPrint('[RejoinScreen] Error parsing alert $alertId: $e');
        }
      });

      debugPrint('[RejoinScreen] Total active alerts for token "$token": ${activeAlerts.length}');

      if (activeAlerts.isEmpty) {
        setState(() { _isSearching = false; _errorMessage = 'No active emergency found for this room code.'; });
        return;
      }

      // Sort newest first
      activeAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (activeAlerts.length == 1) {
        // Only one active alert, jump directly to it
        await _selectAlert(activeAlerts.first);
      } else {
        // Multiple alerts, display the list
        setState(() {
          _isSearching = false;
          _foundAlerts = activeAlerts;
        });
      }
    } catch (e) {
      setState(() { _isSearching = false; _errorMessage = 'Could not connect. Please check your connection.'; });
    }
  }

  Future<void> _selectAlert(Alert alert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_alert_id', alert.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => StatusScreen(alertId: alert.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.vpn_key_outlined, color: Colors.orangeAccent, size: 44),
              const SizedBox(height: 20),
              const Text(
                'Rejoin Emergency',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-character room code shown on the CrisisNet app when your emergency was submitted.',
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _tokenController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8, fontSize: 28),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orangeAccent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                  ],
                ),
              ],
              
              if (_foundAlerts.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Active Emergencies',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildAlertList()),
              ] else ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _findAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.grey[800],
                    ),
                    child: _isSearching
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Find My Emergency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertList() {
    return ListView.separated(
      itemCount: _foundAlerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alert = _foundAlerts[index];
        final timeStr = DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(alert.timestamp));
        final typeStr = alert.type?.name.toUpperCase() ?? 'OTHER';
        final statusStr = alert.status.name.toUpperCase();

        IconData getIconForType() {
          switch (alert.type) {
            case EmergencyType.fire: return Icons.local_fire_department;
            case EmergencyType.medical: return Icons.medical_services;
            case EmergencyType.security: return Icons.security;
            case EmergencyType.infrastructure: return Icons.construction;
            default: return Icons.warning_amber_rounded;
          }
        }

        return InkWell(
          onTap: () => _selectAlert(alert),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(getIconForType(), color: Colors.orangeAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$typeStr EMERGENCY',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location: Floor ${alert.floor}, ${alert.roomNumber}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      statusStr,
                      style: TextStyle(
                        color: alert.status == AlertStatus.pending ? Colors.orangeAccent : Colors.blueAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
