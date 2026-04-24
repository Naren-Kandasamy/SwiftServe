import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:shared/models/incident.dart';
import 'package:shared/models/alert.dart';
import '../services/pdf_service.dart';
import 'incident_chat_dialog.dart';
import 'internal_chat_dialog.dart';
import 'timeline_entry.dart';
import 'package:shared/models/user.dart';

class IncidentCard extends StatefulWidget {
  final Incident incidentData;
  final VoidCallback onAssign;
  final VoidCallback onEscalate;
  final VoidCallback onResolve;
  final UserRole currentRole;

  const IncidentCard({
    super.key,
    required this.incidentData,
    required this.onAssign,
    required this.onEscalate,
    required this.onResolve,
    required this.currentRole,
  });

  @override
  State<IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<IncidentCard> {
  bool _isGenerating = false;
  bool _timelineExpanded = false;

  Color _getSeverityColor(int severity, IncidentStatus status) {
    if (status == IncidentStatus.reviewPending) {
      return Colors.purpleAccent;
    }
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
    final String title = 'Emergency: ${widget.incidentData.type.name.toUpperCase()}';
    final String roomNumber = widget.incidentData.affectedZone;
    final EmergencyType type = widget.incidentData.type;
    final int severity = widget.incidentData.severity;
    final DateTime timeObj = DateTime.fromMillisecondsSinceEpoch(widget.incidentData.createdAt);
    final String time = '${timeObj.hour}:${timeObj.minute.toString().padLeft(2, '0')}';
    
    // Derive assigned string from the timeline updates if any exist containing 'Assigned'
    final String? assigned = widget.incidentData.timeline.where((t) => t.updateText.contains('Assigned')).map((t) => t.updateText.replaceFirst('Assigned to ', '')).lastOrNull;
    final bool escalated = widget.incidentData.status == IncidentStatus.escalated;
    final bool reviewPending = widget.incidentData.status == IncidentStatus.reviewPending;
    
    final severityColor = _getSeverityColor(severity, widget.incidentData.status);
    
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
                    if (reviewPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple[900]?.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('REV PEND', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                TextButton.icon(
                  onPressed: _isGenerating ? null : () async {
                    setState(() => _isGenerating = true);
                    try {
                      final url = await PdfService.generateBriefUrl(widget.incidentData);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 16, right: 16),
                          elevation: 10,
                          backgroundColor: Colors.green[800],
                          duration: const Duration(seconds: 6),
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Responder Brief ready!', style: TextStyle(color: Colors.white))),
                              TextButton(
                                onPressed: () {
                                  html.window.navigator.clipboard?.writeText(url);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link copied to clipboard')),
                                  );
                                },
                                child: const Text('COPY', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                              ),
                            ],
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red[900],
                          content: Text('Brief failed: ${e.toString().split('\n').first}', style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isGenerating = false);
                    }
                  },
                  icon: _isGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                    : const Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 16),
                  label: Text(_isGenerating ? 'Generating...' : 'Brief', style: const TextStyle(color: Colors.blueAccent)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => IncidentChatDialog(incident: widget.incidentData),
                    );
                  },
                  icon: const Icon(Icons.chat, color: Colors.greenAccent, size: 16),
                  label: const Text('Guest Chat', style: TextStyle(color: Colors.greenAccent)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => InternalChatDialog(incident: widget.incidentData, currentRole: widget.currentRole),
                    );
                  },
                  icon: const Icon(Icons.people, color: Colors.purpleAccent, size: 16),
                  label: const Text('Internal', style: TextStyle(color: Colors.purpleAccent)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (assigned != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(assigned, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: widget.onAssign,
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Assign', style: TextStyle(color: Colors.lightBlue, fontSize: 13)),
                      ),
                    ],
                    ElevatedButton(
                      onPressed: escalated ? null : widget.onEscalate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[800],
                        disabledForegroundColor: Colors.white30,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(escalated ? 'Escalated' : 'Escalate'),
                    ),
                    ElevatedButton(
                      // Role and state based disable logic
                      onPressed: (reviewPending ? (widget.currentRole == UserRole.admin) : (widget.currentRole != UserRole.admin)) ? widget.onResolve : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[800],
                        disabledForegroundColor: Colors.white30,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        reviewPending
                            ? (widget.currentRole == UserRole.admin ? 'Confirm Resolve' : 'Awaiting Admin')
                            : (widget.currentRole == UserRole.admin ? 'Awaiting Staff' : 'Request Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ── Timeline toggle ─────────────────────────────────────────
            if (widget.incidentData.timeline.isNotEmpty) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _timelineExpanded = !_timelineExpanded),
                child: Row(
                  children: [
                    Icon(
                      _timelineExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TIMELINE (${widget.incidentData.timeline.length})',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: _timelineExpanded
                  ? Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < widget.incidentData.timeline.length; i++)
                            TimelineEntry(
                              update: widget.incidentData.timeline[i],
                              isFirst: i == 0,
                              isLast: i == widget.incidentData.timeline.length - 1,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
