import 'package:flutter/material.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/models/alert.dart';
import '../services/pdf_service.dart';

class IncidentCard extends StatelessWidget {
  final Incident incidentData;
  final VoidCallback onAssign;
  final VoidCallback onEscalate;

  const IncidentCard({
    super.key,
    required this.incidentData,
    required this.onAssign,
    required this.onEscalate,
  });

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1: return Colors.blueGrey;
      case 2: return Colors.blue;
      case 3: return Colors.amber;
      case 4: return Colors.orange;
      case 5: return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  IconData _getEmergencyIcon(EmergencyType type) {
    switch (type) {
      case EmergencyType.fire: return Icons.local_fire_department;
      case EmergencyType.medical: return Icons.medical_services;
      case EmergencyType.security: return Icons.security;
      case EmergencyType.infrastructure: return Icons.construction;
      case EmergencyType.other: return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = 'Emergency: ${incidentData.type.name.toUpperCase()}';
    final String roomNumber = incidentData.affectedZone;
    final EmergencyType type = incidentData.type;
    final int severity = incidentData.severity;
    final DateTime timeObj = DateTime.fromMillisecondsSinceEpoch(incidentData.createdAt);
    final String time = '${timeObj.hour}:${timeObj.minute.toString().padLeft(2, '0')}';
    
    // Derive assigned string from the timeline updates if any exist containing 'Assigned'
    final String? assigned = incidentData.timeline.where((t) => t.updateText.contains('Assigned')).map((t) => t.updateText.replaceFirst('Assigned to ', '')).lastOrNull;
    final bool escalated = incidentData.status == IncidentStatus.escalated;
    
    final severityColor = _getSeverityColor(severity);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: severityColor, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(_getEmergencyIcon(type), color: severityColor, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'L$severity',
                        style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (escalated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[900]?.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ESC', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(roomNumber, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                const Icon(Icons.access_time, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(time, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => PdfService.generateBrief(incidentData),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 16),
                  label: const Text('Brief', style: TextStyle(color: Colors.blueAccent)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                
                if (assigned != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text('Assigned to: $assigned', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onAssign,
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Assign', style: TextStyle(color: Colors.lightBlue)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: escalated ? null : onEscalate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[800],
                          disabledForegroundColor: Colors.white30,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(escalated ? 'Escalated' : 'Escalate'),
                      ),
                    ],
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}
