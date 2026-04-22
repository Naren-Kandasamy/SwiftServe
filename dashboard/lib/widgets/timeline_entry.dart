import 'package:flutter/material.dart';
import 'package:shared/models/incident.dart';

/// A single row in the incident timeline audit trail.
/// Shows a coloured icon, event text, and formatted timestamp,
/// connected to adjacent entries by a neon dotted vertical line.
class TimelineEntry extends StatelessWidget {
  final IncidentUpdate update;
  final bool isFirst;
  final bool isLast;

  const TimelineEntry({
    super.key,
    required this.update,
    this.isFirst = false,
    this.isLast = false,
  });

  static Color _colorForText(String text) {
    final t = text.toLowerCase();
    if (t.contains('escalat')) return Colors.redAccent;
    if (t.contains('resolv')) return Colors.greenAccent;
    if (t.contains('assign')) return Colors.lightBlueAccent;
    if (t.contains('triage') || t.contains('ai')) return Colors.purpleAccent;
    if (t.contains('sos') || t.contains('received')) return Colors.orangeAccent;
    return Colors.white54;
  }

  static IconData _iconForText(String text) {
    final t = text.toLowerCase();
    if (t.contains('escalat')) return Icons.warning_amber_rounded;
    if (t.contains('resolv')) return Icons.check_circle_outline;
    if (t.contains('assign')) return Icons.person_outline;
    if (t.contains('triage') || t.contains('ai')) return Icons.psychology_outlined;
    if (t.contains('sos') || t.contains('received')) return Icons.notifications_active_outlined;
    return Icons.radio_button_unchecked;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForText(update.updateText);
    final icon  = _iconForText(update.updateText);
    final dt    = DateTime.fromMillisecondsSinceEpoch(update.timestamp);
    final timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left connector rail ──────────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Line above dot (hidden on first entry)
                Expanded(
                  child: isFirst
                    ? const SizedBox()
                    : Center(child: Container(width: 1.5, color: Colors.white12)),
                ),
                // The coloured dot
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.25),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(icon, size: 7, color: color),
                ),
                // Line below dot (hidden on last entry)
                Expanded(
                  child: isLast
                    ? const SizedBox()
                    : Center(child: Container(width: 1.5, color: Colors.white12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Event text + timestamp ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      update.updateText,
                      style: TextStyle(
                        color: color == Colors.white54 ? Colors.white70 : color,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
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
}
