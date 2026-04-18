import 'package:flutter/material.dart';
import '../services/offline_knowledge.dart';

class KnowledgeLibraryScreen extends StatelessWidget {
  const KnowledgeLibraryScreen({super.key});

  static const List<Map<String, dynamic>> _guides = [
    {'title': 'Fire Emergency', 'icon': Icons.local_fire_department, 'path': 'assets/knowledge/fire.html'},
    {'title': 'Medical / CPR', 'icon': Icons.medical_services, 'path': 'assets/knowledge/medical_cpr.html'},
    {'title': 'Choking (Heimlich)', 'icon': Icons.restaurant, 'path': 'assets/knowledge/choking.html'},
    {'title': 'Cardiac Arrest', 'icon': Icons.monitor_heart, 'path': 'assets/knowledge/cardiac.html'},
    {'title': 'Severe Wounds', 'icon': Icons.healing, 'path': 'assets/knowledge/wounds.html'},
    {'title': 'Burns', 'icon': Icons.thermostat, 'path': 'assets/knowledge/burns.html'},
    {'title': 'Security Threat', 'icon': Icons.gavel, 'path': 'assets/knowledge/security.html'},
    {'title': 'Gas Leak', 'icon': Icons.warning_amber, 'path': 'assets/knowledge/gas_leak.html'},
    {'title': 'Earthquake', 'icon': Icons.landslide, 'path': 'assets/knowledge/earthquake.html'},
    {'title': 'Flood', 'icon': Icons.water, 'path': 'assets/knowledge/flood.html'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Emergency Library', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[900]?.withValues(alpha: 0.2),
              child: const Row(
                children: [
                  Icon(Icons.offline_bolt, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These guides are stored securely on your device and are accessible 100% offline during blackouts.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _guides.length,
                itemBuilder: (context, index) {
                  final guide = _guides[index];
                  return Material(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        OfflineKnowledgeService.showCustomKnowledgeScreen(
                          context,
                          guide['title'],
                          guide['path'],
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(guide['icon'], size: 36, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              guide['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
          ],
        ),
      ),
    );
  }
}
