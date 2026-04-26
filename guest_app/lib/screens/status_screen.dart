import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';
import 'sos_screen.dart';
import 'chat_panel.dart';

class StatusScreen extends StatefulWidget {
  final String alertId;
  const StatusScreen({super.key, required this.alertId});

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
    _listenToAlert();
    _listenToIncident();
  }

  void _listenToAlert() {
    _alertSub = FirebaseDatabase.instance
        .ref('venues/$_venueId/alerts/${widget.alertId}')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _alert = Alert.fromMap(Map<dynamic, dynamic>.from(event.snapshot.value as Map));
        });
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
        title: const Text('Emergency Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    const Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text('AI SAFETY INSTRUCTIONS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _alert!.safetyInstructions!,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                      SizedBox(height: 16),
                      Text('Gemini AI analyzing situation...', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),

            // Live Timeline Log
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'LIVE UPDATES',
                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            
            Expanded(
              child: _incident == null
                  ? const Center(child: Text('Connecting to responder network...', style: TextStyle(color: Colors.white30)))
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
                    isAssigned ? 'STAFF DISPATCHED – EN ROUTE' : 'HELP IS ON THE WAY',
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
