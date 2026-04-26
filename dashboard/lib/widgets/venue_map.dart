import 'dart:math' show pi;
import 'dart:ui';
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

class _VenueMapState extends State<VenueMap> with TickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  String _currentFloor = VenueConfig.floors.first;

  late AnimationController _radarController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _glowController  = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  void _zoomIn()   => _controller.value = Matrix4.identity()..scale(1.2);
  void _zoomOut()  => _controller.value = Matrix4.identity()..scale(0.83);
  void _resetZoom()=> _controller.value = Matrix4.identity();

  @override
  void dispose() {
    _radarController.dispose();
    _glowController.dispose();
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
            child: AnimatedBuilder(
              animation: Listenable.merge([_radarController, _glowController]),
              builder: (context, _) => InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                transformationController: _controller,
                minScale: 0.1,
                maxScale: 3.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                constrained: false,
                child: SizedBox(
                  width: 2000,
                  height: 1500,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ),
                    child: Stack(
                      key: ValueKey(_currentFloor),
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [Colors.purpleAccent.withValues(alpha: 0.05), Colors.transparent],
                                radius: 0.8,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FloorGridPainter(
                              floor: _currentFloor,
                              radarFraction: _radarController.value,
                              glowAlpha: 0.10 + (_glowController.value * 0.30),
                            ),
                          ),
                        ),
                        // Room label overlays
                        ..._buildRoomLabels(2000, 1500),
                        // Live incident pins
                        ..._renderIncidentPins(2000, 1500),
                      ],
                    ),
                  ),
                ),
              ),
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

          // ── Severity Legend Panel ──────────────────────────────────
          Positioned(
            bottom: 60,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xBB1c053a),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('SEVERITY', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, decoration: TextDecoration.none)),
                  const SizedBox(height: 6),
                  _legendRow(Colors.red, 'Sev 5 — Critical'),
                  _legendRow(Colors.orange, 'Sev 4 — High'),
                  _legendRow(Colors.amber, 'Sev 3 — Medium'),
                  _legendRow(Colors.lightBlueAccent, 'Sev 2 — Low'),
                ],
              ),
            ),
          ),

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

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  IconData _iconForRoom(String name) {
    name = name.toLowerCase();
    if (name.contains('stair')) return Icons.stairs_outlined;
    if (name.contains('elevator')) return Icons.elevator_outlined;
    if (name.contains('room') || name.contains('suite') || name.contains('penthouse')) return Icons.bed_outlined;
    if (name.contains('restaurant') || name.contains('bar')) return Icons.local_dining_outlined;
    if (name.contains('gym')) return Icons.fitness_center_outlined;
    if (name.contains('pool') || name.contains('spa')) return Icons.pool_outlined;
    if (name.contains('lounge') || name.contains('lobby') || name.contains('desk') || name.contains('office') || name.contains('conference')) return Icons.meeting_room_outlined;
    if (name.contains('storage') || name.contains('laundry')) return Icons.local_laundry_service_outlined;
    if (name.contains('ice') || name.contains('vending')) return Icons.ac_unit_outlined;
    if (name.contains('corridor')) return Icons.compare_arrows_outlined;
    return Icons.place_outlined;
  }



  List<Widget> _buildRoomLabels(double w, double h) {
    final rooms = VenueConfig.roomsForFloor(_currentFloor);
    return rooms.map((room) {
      final (rx, ry) = VenueConfig.coordinateFor(_currentFloor, room);
      return Positioned(
        left: (rx * w - 36).clamp(0, w - 72),
        top: (ry * h - 14).clamp(0, h - 28),
        child: Opacity(
          opacity: 0.80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xDD1c053a),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconForRoom(room), size: 12, color: Colors.cyanAccent),
                const SizedBox(width: 4),
                Text(room, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      );
    }).toList();
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

      final px = (rx * w - 18).clamp(0.0, w - 36);
      final py = (ry * h - 36).clamp(0.0, h - 52);

      return Positioned(
        left: px,
        top: py,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding sonar ring
            AnimatedBuilder(
              animation: _radarController,
              builder: (_, __) {
                final scale = 1.0 + _radarController.value * 2.0;
                final alpha = (1.0 - _radarController.value) * 0.6;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: severityColor.withValues(alpha: alpha), width: 2),
                    ),
                  ),
                );
              },
            ),
            _HoverablePin(incident: incident, color: severityColor),
          ],
        ),
      );
    }).toList();
  }
}

class _FloorGridPainter extends CustomPainter {
  final String floor;
  final double radarFraction;
  final double glowAlpha;

  _FloorGridPainter({
    required this.floor,
    required this.radarFraction,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Base fill ─────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1c053a).withValues(alpha: 0.88)..style = PaintingStyle.fill,
    );

    // ── Fine grid ─────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.12)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final step = size.height * 0.05;
    for (double x = 0; x <= size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y <= size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    // ── Outer perimeter — breathing glow ──────────────────────────────
    final perimRect = Rect.fromLTWH(size.width * 0.04, size.height * 0.05, size.width * 0.92, size.height * 0.90);
    canvas.drawRect(perimRect, Paint()
      ..color = Colors.deepOrangeAccent.withValues(alpha: glowAlpha)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke);
    canvas.drawRect(perimRect, Paint()
      ..color = Colors.deepOrangeAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);

    // ── Concentric radar distance rings ───────────────────────────────
    final ringPaint = Paint()
      ..color = const Color(0x1800FFAA)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (final frac in [0.25, 0.50, 0.75]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.92 * frac,
          height: size.height * 0.90 * frac,
        ),
        ringPaint,
      );
    }

    // ── Room-type zone shading ────────────────────────────────────────
    Color _zoneColor(String name) {
      final n = name.toLowerCase();
      if (n.contains('stair') || n.contains('elevator') || n.contains('corridor')) return const Color(0x22FFAA00); // amber — transit
      if (n.contains('restaurant') || n.contains('bar') || n.contains('pool') || n.contains('gym') || n.contains('spa')) return const Color(0x2200AAFF); // blue — amenity
      if (n.contains('lobby') || n.contains('desk') || n.contains('office') || n.contains('conference') || n.contains('lounge') || n.contains('business')) return const Color(0x22AA00FF); // purple — staff/meeting
      if (n.contains('storage') || n.contains('laundry') || n.contains('ice') || n.contains('vending')) return const Color(0x22555555); // grey — utility
      return const Color(0x2200FF88); // green — guest rooms
    }

    // ── L-shaped corridor paths ────────────────────────────────────────
    final spineY = size.height * 0.50;
    final glowPaint = Paint()
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.22)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = Colors.deepOrangeAccent
      ..style = PaintingStyle.fill;

    // Draw horizontal spine
    canvas.drawLine(Offset(size.width * 0.05, spineY), Offset(size.width * 0.95, spineY), glowPaint);
    canvas.drawLine(Offset(size.width * 0.05, spineY), Offset(size.width * 0.95, spineY), linePaint);

    final rooms = VenueConfig.roomsForFloor(floor);
    // Index for staggering data-packet offsets per corridor
    int roomIndex = 0;
    for (final room in rooms) {
      final (rx, ry) = VenueConfig.coordinateFor(floor, room);
      final roomX = rx * size.width;
      final roomY = ry * size.height;
      final elbowX = cx;

      // Zone shading — filled circle behind the node
      canvas.drawCircle(Offset(roomX, roomY), 18, Paint()..color = _zoneColor(room)..style = PaintingStyle.fill);

      final path = Path()
        ..moveTo(roomX, roomY)
        ..lineTo(elbowX, roomY)
        ..lineTo(elbowX, spineY);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Junction dot at elbow
      canvas.drawCircle(Offset(elbowX, roomY), 4, dotPaint);

      // Room node dot
      canvas.drawCircle(Offset(roomX, roomY), 5,
        Paint()..color = Colors.pinkAccent.withValues(alpha: 0.6)..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(roomX, roomY), 5,
        Paint()..color = Colors.pinkAccent..strokeWidth = 1..style = PaintingStyle.stroke);

      // ── Animated data packet travelling along the L-path ──────────
      // Each room gets a staggered offset so they don't all move in sync
      final stagger = (roomIndex * 0.13) % 1.0;
      final t = (radarFraction + stagger) % 1.0;
      // L-path total length ≈ |roomX - elbowX| + |roomY - spineY|
      final hLen = (elbowX - roomX).abs();
      final vLen = (spineY - roomY).abs();
      final totalLen = hLen + vLen;
      if (totalLen > 0) {
        final traveled = t * totalLen;
        Offset packetPos;
        if (traveled <= hLen) {
          // Still on horizontal segment
          final frac = traveled / hLen;
          packetPos = Offset(roomX + (elbowX - roomX) * frac, roomY);
        } else {
          // On vertical segment
          final frac = (traveled - hLen) / vLen;
          packetPos = Offset(elbowX, roomY + (spineY - roomY) * frac);
        }
        canvas.drawCircle(packetPos, 3,
          Paint()..color = Colors.cyanAccent.withValues(alpha: 0.9)..style = PaintingStyle.fill);
        // Trailing glow
        canvas.drawCircle(packetPos, 6,
          Paint()..color = Colors.cyanAccent.withValues(alpha: 0.25)..style = PaintingStyle.fill);
      }
      roomIndex++;
    }

    // ── Radar sweep arc — hard-clipped to perimeter ───────────────────
    canvas.save();
    canvas.clipRect(perimRect);

    final sweepAngle = pi / 5; // 36° wedge
    final startAngle = radarFraction * 2 * pi;
    final sweepRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width * 0.92,
      height: size.height * 0.90,
    );
    canvas.drawArc(
      sweepRect, startAngle, sweepAngle, true,
      Paint()
        ..color = const Color(0x2200FFAA)
        ..style = PaintingStyle.fill,
    );
    canvas.drawArc(
      sweepRect, startAngle, 0.025, false,
      Paint()
        ..color = const Color(0xAA00FFAA)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();

    // ── Vignette — dark fade around map edges ─────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, const Color(0xFF0a0115)],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_FloorGridPainter old) =>
      old.radarFraction != radarFraction ||
      old.glowAlpha != glowAlpha ||
      old.floor != floor;
}

/// A stateful pin that reveals a detail tooltip card on hover.
class _HoverablePin extends StatefulWidget {
  final Incident incident;
  final Color color;
  const _HoverablePin({required this.incident, required this.color});

  @override
  State<_HoverablePin> createState() => _HoverablePinState();
}

class _HoverablePinState extends State<_HoverablePin> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // High severity = fast pulse, Low severity = slow pulse
    int speedMs = widget.incident.severity >= 4 ? 600 : 1500;
    _pulseController = AnimationController(vsync: this, duration: Duration(milliseconds: speedMs))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Cyberpunk pulsing pin
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: _hovered ? 0.9 : 0.4 + (_pulseController.value * 0.4)),
                          blurRadius: _hovered ? 25 : 10 + (_pulseController.value * 10),
                          spreadRadius: _hovered ? 8 : 4 + (_pulseController.value * 6),
                        )
                      ],
                    ),
                    child: Icon(
                      _iconForType(widget.incident.type),
                      color: Colors.white,
                      size: _hovered ? 24 : 18,
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 14,
                    color: widget.color.withValues(alpha: 0.8),
                  ),
                ],
              );
            }
          ),

          // Glassmorphic Tooltip card shown on hover
          if (_hovered)
            Positioned(
              bottom: 52,
              left: -110,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.color.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.2),
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
