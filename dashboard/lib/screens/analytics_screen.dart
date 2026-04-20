import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/models/alert.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const String _venueId = 'mockVenue123';
  List<Incident> _incidents = [];

  @override
  void initState() {
    super.initState();
    _subscribeToIncidents();
  }

  void _subscribeToIncidents() {
    FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        setState(() => _incidents = []);
        return;
      }
      final data = event.snapshot.value;
      if (data is! Map) return;

      final List<Incident> updated = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            updated.add(Incident.fromMap(Map<dynamic, dynamic>.from(value)));
          } catch (_) {}
        }
      });
      setState(() => _incidents = updated);
    });
  }

  String _calculateAverageResolutionTime() {
    final resolved = _incidents.where((i) => i.status == IncidentStatus.resolved);
    if (resolved.isEmpty) return "N/A";

    int totalDeltaMs = 0;
    for (var i in resolved) {
      // Find the "Assigned" or "Resolved" timestamp in the timeline 
      // Teammate added a Resolve button which presumably updates the IncidentStatus to resolved.
      // We will look for timeline events indicating resolution, or fallback to now if missing.
      final resolveEvent = i.timeline.reversed.firstWhere((t) => t.updateText.toLowerCase().contains("resolved"), orElse: () => i.timeline.last);
      totalDeltaMs += (resolveEvent.timestamp - i.createdAt);
    }
    final avgMinutes = (totalDeltaMs / resolved.length) / 60000;
    if (avgMinutes < 1) return "< 1 min";
    return "${avgMinutes.round()} mins";
  }

  Map<EmergencyType, int> _getTypeDistribution() {
    Map<EmergencyType, int> dist = {};
    for (var i in _incidents) {
      dist[i.type] = (dist[i.type] ?? 0) + 1;
    }
    return dist;
  }

  Color _getColorForType(EmergencyType type) {
    if (type == EmergencyType.fire) return Colors.red;
    if (type == EmergencyType.medical) return Colors.blue;
    if (type == EmergencyType.security) return Colors.amber;
    if (type == EmergencyType.infrastructure) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final dist = _getTypeDistribution();
    final resolveTime = _calculateAverageResolutionTime();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Performance & Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aggregate Activity', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Data is completely anonymized. Metric thresholds compute securely off event timestamps.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total Incidents Logged',
                    value: _incidents.length.toString(),
                    icon: Icons.assignment_late,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    title: 'Avg. Resolution Time',
                    value: resolveTime,
                    icon: Icons.timer,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    title: 'Currently Active',
                    value: _incidents.where((i) => i.status == IncidentStatus.active || i.status == IncidentStatus.escalated).length.toString(),
                    icon: Icons.warning_amber,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            const Text('Incident Typology Distribution', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            if (_incidents.isEmpty)
              const SizedBox(
                height: 300,
                child: Center(child: Text("Waiting for incoming alerts to aggregate graph...", style: TextStyle(color: Colors.white54))),
              )
            else
              SizedBox(
                height: 300,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 60,
                          sections: dist.entries.map((e) {
                            return PieChartSectionData(
                              color: _getColorForType(e.key),
                              value: e.value.toDouble(),
                              title: '${e.value}',
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dist.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(width: 16, height: 16, color: _getColorForType(e.key)),
                                const SizedBox(width: 8),
                                Text(e.key.name.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: Colors.blueGrey[200], fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
