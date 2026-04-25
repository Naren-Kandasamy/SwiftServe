import 'package:flutter/material.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/models/user.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/venue_map.dart';
import '../widgets/incident_chat_dialog.dart';
import '../widgets/timeline_entry.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ResponderViewScreen extends StatefulWidget {
  final Incident incident;

  const ResponderViewScreen({super.key, required this.incident});

  @override
  State<ResponderViewScreen> createState() => _ResponderViewScreenState();
}

class _ResponderViewScreenState extends State<ResponderViewScreen> {
  late Incident _incident;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    _subscribeToIncident();
  }

  void _subscribeToIncident() {
    FirebaseDatabase.instance
        .ref('venues/${_incident.venueId}/incidents/${_incident.id}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _incident = Incident.fromMap(Map<dynamic, dynamic>.from(data));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd, yyyy - HH:mm:ss');
    final timeStr = formatter.format(DateTime.fromMillisecondsSinceEpoch(_incident.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: Colors.orange[900],
        title: const Text('CRISISNET LIVE BRIEFING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                final url = await PdfService.generateBriefUrl(_incident);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Brief downloaded successfully.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to download brief: $e')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('Download Brief', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent[700],
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              _incident.timeline.add(IncidentUpdate(
                timestamp: DateTime.now().millisecondsSinceEpoch,
                updateText: 'Emergency Services arrived ON SCENE.',
              ));
              await FirebaseDatabase.instance
                  .ref('venues/${_incident.venueId}/incidents/${_incident.id}')
                  .update({'timeline': _incident.timeline.map((u) => u.toMap()).toList()});
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Status updated to On Scene.')),
              );
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('MARK ON SCENE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Map and Metadata
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orangeAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: VenueMap(
                        incidents: [_incident],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('INCIDENT ID', _incident.id.toUpperCase(), Icons.numbers)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoCard('TIME', timeStr, Icons.access_time)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('ZONE', _incident.affectedZone, Icons.location_on)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoCard('SEVERITY', 'LEVEL ${_incident.severity}', Icons.warning, Colors.redAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Column: Chat and Timeline
          Expanded(
            flex: 1,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black26,
                border: Border(left: BorderSide(color: Colors.white12, width: 2)),
              ),
              child: Column(
                children: [
                  // Guest Chat
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[900],
                          width: double.infinity,
                          child: const Text('GUEST CHAT - RESPONDER ACCESS', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                        Expanded(
                          child: IncidentChatDialog(
                            incident: _incident,
                            currentRole: UserRole.admin, // Use admin role structurally
                            teamId: 'RESPONDER', // Label them as RESPONDER
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timeline
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white12, width: 2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey[900],
                            width: double.infinity,
                            child: const Text('INCIDENT TIMELINE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _incident.timeline.length,
                              itemBuilder: (context, index) {
                                return TimelineEntry(update: _incident.timeline[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, [Color? textColor]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: textColor ?? Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
