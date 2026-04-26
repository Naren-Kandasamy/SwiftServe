import 'package:flutter/material.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/venue_config.dart';

class VenueMap extends StatefulWidget {
  final List<Incident> incidents;
  const VenueMap({super.key, this.incidents = const []});

  @override
  State<VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<VenueMap> {
  final TransformationController _controller = TransformationController();
  String _currentFloor = VenueConfig.floors.first;

  void _zoomIn() => _controller.value = Matrix4.identity()..scale(1.2);
  void _zoomOut() => _controller.value = Matrix4.identity()..scale(0.83);
  void _resetZoom() => _controller.value = Matrix4.identity();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          // ── Floor Plan / Map Area ───────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.3,
              maxScale: 5.0,
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      // Hardcoded floor canvas grid + room labels
                      Positioned.fill(child: _buildFloorCanvas(w, h)),
                      // Live incident pins — all sharing the same (w, h)
                      ..._renderIncidentPins(w, h),
                    ],
                  ),
                );
              }),
            ),
          ),

          // ── Top Bar: title + upload button ─────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                const Text(
                  'VENUE MAP',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _currentFloor,
                  dropdownColor: const Color(0xFF2C2C3E),
                  focusColor: Colors.transparent,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 20),
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  items: VenueConfig.floors
                      .map((f) => DropdownMenuItem(value: f, child: Text("Floor $f")))
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentFloor) {
                      setState(() => _currentFloor = val);
                      _resetZoom();
                    }
                  },
                ),
                const Spacer(),
              ],
            ),
          ),

          // ── Zoom Controls ───────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                _mapControl(Icons.add, _zoomIn, 'zoomIn'),
                const SizedBox(height: 6),
                _mapControl(Icons.remove, _zoomOut, 'zoomOut'),
                const SizedBox(height: 6),
                _mapControl(Icons.center_focus_strong, _resetZoom, 'zoomReset'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCanvas(double w, double h) {
    final rooms = VenueConfig.roomsForFloor(_currentFloor);
    return CustomPaint(
      painter: _FloorGridPainter(),
      child: Stack(
        children: rooms.map((room) {
          final (rx, ry) = VenueConfig.coordinateFor(_currentFloor, room);
          return Positioned(
            left: (rx * w - 24).clamp(0, w - 48),
            top: (ry * h - 14).clamp(0, h - 28),
            child: Opacity(
              opacity: 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(room, style: const TextStyle(color: Colors.white70, fontSize: 9, decoration: TextDecoration.none)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No floor data', style: TextStyle(color: Colors.white24)));
  }

  Widget _mapControl(IconData icon, VoidCallback onTap, String heroTag) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: Colors.grey[850],
      elevation: 2,
      onPressed: onTap,
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  List<Widget> _renderIncidentPins(double w, double h) {
    final floorIncidents = widget.incidents
        .where((i) => i.affectedZone.contains('(Floor $_currentFloor)'))
        .toList();

    return floorIncidents.map((incident) {
      // Parse room name from "Room 206 (Floor 2)" → "Room 206"
      final rawZone = incident.affectedZone.split(' (Floor').first.trim();
      final (rx, ry) = VenueConfig.coordinateFor(_currentFloor, rawZone);

      Color severityColor;
      switch (incident.severity) {
        case 5: severityColor = Colors.red; break;
        case 4: severityColor = Colors.orange; break;
        case 3: severityColor = Colors.amber; break;
        case 2: severityColor = Colors.lightBlueAccent; break;
        default: severityColor = Colors.grey; break;
      }

      return Positioned(
        left: (rx * w - 18).clamp(0, w - 36),
        top: (ry * h - 36).clamp(0, h - 52),
        child: _HoverablePin(incident: incident, color: severityColor),
      );
    }).toList();
  }
}

// ─── Floor Grid Canvas Painter ───────────────────────────────────────────────
class _FloorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = const Color(0xFF1E2035)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final wall = Paint()
      ..color = const Color(0xFF3E4060)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    // Outer perimeter
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.04, size.height * 0.05, size.width * 0.92, size.height * 0.90),
      wall,
    );

    final grid = Paint()
      ..color = const Color(0xFF2A2C45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    // Horizontal corridor
    canvas.drawLine(Offset(size.width * 0.04, size.height * 0.50), Offset(size.width * 0.96, size.height * 0.50), grid);
    // Vertical corridor
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.05), Offset(size.width * 0.50, size.height * 0.95), grid);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// A stateful pin that reveals a detail tooltip card on hover.
class _HoverablePin extends StatefulWidget {
  final Incident incident;
  final Color color;
  const _HoverablePin({required this.incident, required this.color});

  @override
  State<_HoverablePin> createState() => _HoverablePinState();
}

class _HoverablePinState extends State<_HoverablePin> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // The pin itself
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _hovered ? 0.8 : 0.4),
                      blurRadius: _hovered ? 20 : 10,
                      spreadRadius: _hovered ? 6 : 3,
                    )
                  ],
                ),
                child: Icon(
                  _iconForType(widget.incident.type),
                  color: Colors.white,
                  size: _hovered ? 22 : 18,
                ),
              ),
              Container(
                width: 3,
                height: 14,
                color: widget.color,
              ),
            ],
          ),

          // Tooltip card shown on hover
          if (_hovered)
            Positioned(
              bottom: 52,
              left: -110,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.color.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_iconForType(widget.incident.type),
                              color: widget.color, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.incident.type.name.toUpperCase(),
                              style: TextStyle(
                                  color: widget.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('L${widget.incident.severity}',
                                style: TextStyle(
                                    color: widget.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _tooltipRow(Icons.location_on, widget.incident.affectedZone),
                      _tooltipRow(Icons.people, '${widget.incident.guestCount} guests affected'),
                      _tooltipRow(
                        Icons.circle,
                        widget.incident.status.name.toUpperCase(),
                        valueColor: widget.incident.status == IncidentStatus.escalated
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                      if (widget.incident.status == IncidentStatus.escalated)
                        _tooltipRow(Icons.warning_amber, 'ESCALATED TO EMERGENCY SERVICES',
                            valueColor: Colors.redAccent),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tooltipRow(IconData icon, String text, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: valueColor ?? Colors.white70,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(EmergencyType type) {
    switch (type) {
      case EmergencyType.fire:
        return Icons.local_fire_department;
      case EmergencyType.medical:
        return Icons.medical_services;
      case EmergencyType.security:
        return Icons.security;
      case EmergencyType.infrastructure:
        return Icons.construction;
      default:
        return Icons.warning_amber;
    }
  }
}
