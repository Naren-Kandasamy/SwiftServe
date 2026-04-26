import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';
import 'sos_screen.dart';
import 'chat_panel.dart';
import '../l10n/app_localizations.dart';
import '../services/offline_knowledge.dart';

class StatusScreen extends StatefulWidget {
  final String alertId;
  final Alert? offlineAlert;
  final String? aiSource;

  const StatusScreen({
    super.key, 
    required this.alertId,
    this.offlineAlert,
    this.aiSource,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Alert? _alert;
  Incident? _incident;
  StreamSubscription<DatabaseEvent>? _alertSub;
  StreamSubscription<DatabaseEvent>? _incidentSub;

  final String _venueId = 'mockVenue123';

  @override
  void initState() {
    super.initState();
    if (widget.offlineAlert != null) {
      _alert = widget.offlineAlert;
    }
    _listenToAlert();
    _listenToIncident();
  }

  void _listenToAlert() {
    _alertSub = FirebaseDatabase.instance
        .ref('venues/$_venueId/alerts/${widget.alertId}')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.value != null) {
        final updatedAlert = Alert.fromMap(Map<dynamic, dynamic>.from(event.snapshot.value as Map));
        setState(() => _alert = updatedAlert);
        // Clear local session when the incident is resolved
        if (updatedAlert.status == AlertStatus.resolved) {
          SharedPreferences.getInstance().then((prefs) => prefs.remove('active_alert_id'));
        }
      }
    });
  }

  void _listenToIncident() {
    final incidentId = 'inc_${widget.alertId.substring(0, 8)}';
    _incidentSub = FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents/$incidentId')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _incident = Incident.fromMap(Map<dynamic, dynamic>.from(event.snapshot.value as Map));
        });
      }
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _incidentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_alert == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    final bool isAssigned = _incident != null && _incident!.timeline.any((t) => t.updateText.contains('Assigned'));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statusTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Return to SOS screen',
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SosScreen()),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Code Chip — always visible so guests/roommates can rejoin
            if (_alert!.roomKey != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, color: Colors.white38, size: 16),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Room Code', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                        FutureBuilder<String?>(
                          future: SharedPreferences.getInstance().then((p) => p.getString('stay_token')),
                          builder: (context, snap) => Text(
                            snap.data?.split('').join(' ') ?? '------',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 4),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('Share with roommates', style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ],
                ),
              ),

            // AI Instructions Header
            if (_alert!.safetyInstructions != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.smart_toy, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text('AI SAFETY INSTRUCTIONS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ],
                        ),
                        if (widget.aiSource != null)
                          Text(
                            'Source: ${widget.aiSource}',
                            style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: SingleChildScrollView(
                        child: Text(
                          _alert!.safetyInstructions!,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                        ),
                      ),
                    ),
                    
                    // High-Fidelity Guide Trigger
                    if (widget.offlineAlert != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.menu_book, size: 20),
                          label: const Text('VIEW HIGH-FIDELITY OFFLINE GUIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            final assetPath = OfflineKnowledgeService.getAssetPath(_alert!.type ?? EmergencyType.other);
                            OfflineKnowledgeService.showCustomKnowledgeScreen(
                              context, 
                              '${(_alert!.type ?? EmergencyType.other).name.toUpperCase()} PROTOCOL', 
                              assetPath
                            );
                          },
                        ),
                      ),

                    if (widget.offlineAlert != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 14),
                            SizedBox(width: 8),
                            Text(
                              'Offline Mode: Alert will sync when online.',
                              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.statusWaiting, style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),

            // Live Timeline Log
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                AppLocalizations.of(context)!.statusInstructions,
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            
            Expanded(
              child: _incident == null
                  ? Center(child: Text(AppLocalizations.of(context)!.statusWaiting, style: const TextStyle(color: Colors.white30)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _incident!.timeline.length,
                      itemBuilder: (context, index) {
                        final update = _incident!.timeline.reversed.toList()[index];
                        final time = DateTime.fromMillisecondsSinceEpoch(update.timestamp);
                        final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  update.updateText,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Live Chat Panel
            if (_incident != null)
              ChatPanel(incident: _incident!),

            // Bottom Status Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isAssigned ? Colors.green[700] : Colors.orange[800],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isAssigned ? Icons.directions_run : Icons.access_time, color: Colors.white),
                  const SizedBox(width: 12),
                    Text(
                    isAssigned
                      ? AppLocalizations.of(context)!.statusAssigned
                      : AppLocalizations.of(context)!.statusWaiting,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
