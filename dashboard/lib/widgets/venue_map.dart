import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';

class VenueMap extends StatefulWidget {
  final List<Incident> incidents;
  const VenueMap({super.key, this.incidents = const []});

  @override
  State<VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<VenueMap> {
  final TransformationController _controller = TransformationController();
  StreamSubscription<DatabaseEvent>? _floorPlanSub;
  String? _floorPlanUrl;
  bool _isUploading = false;
  String _currentFloor = '1';

  @override
  void initState() {
    super.initState();
    _loadFloorPlanUrl();
  }

  void _loadFloorPlanUrl() {
    _floorPlanSub?.cancel();
    _floorPlanSub = FirebaseDatabase.instance
        .ref('venues/mockVenue123/floorPlanUrls/$_currentFloor')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => _floorPlanUrl = event.snapshot.value as String);
      }
    });
  }

  Future<void> _uploadFloorPlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final file = result.files.first;
      final ref = FirebaseStorage.instance
          .ref('venues/mockVenue123/floorplan_f$_currentFloor.${file.extension}');
      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL();
      await FirebaseDatabase.instance
          .ref('venues/mockVenue123/floorPlanUrls/$_currentFloor')
          .set(url);
    } catch (e) {
      debugPrint('[VenueMap] Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _zoomIn() => _controller.value = _controller.value.scaled(1.2);
  void _zoomOut() => _controller.value = _controller.value.scaled(0.83);
  void _resetZoom() => _controller.value = Matrix4.identity();

  @override
  void dispose() {
    _floorPlanSub?.cancel();
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
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    // Floor plan background
                    Positioned.fill(
                      child: _floorPlanUrl != null
                          ? Image.network(
                              _floorPlanUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildEmptyState(),
                            )
                          : _buildEmptyState(),
                    ),
                    // Live incident pins
                    ..._renderIncidentPins(),
                  ],
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
                  items: ['1', '2', '3', '4', '5']
                      .map((f) => DropdownMenuItem(value: f, child: Text("Floor $f")))
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentFloor) {
                      setState(() {
                        _currentFloor = val;
                        _floorPlanUrl = null; // Clear brief flash
                      });
                      _loadFloorPlanUrl();
                      _resetZoom();
                    }
                  },
                ),
                const Spacer(),
                if (_isUploading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.blueAccent, strokeWidth: 2),
                  )
                else
                  Tooltip(
                    message: 'Upload floor plan image',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _uploadFloorPlan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.upload_file,
                                size: 14, color: Colors.blueAccent),
                            SizedBox(width: 6),
                            Text('Upload Plan',
                                style: TextStyle(
                                    color: Colors.blueAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 12),
          const Text('No floor plan uploaded',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _uploadFloorPlan,
            icon: const Icon(Icons.upload_file,
                size: 16, color: Colors.blueAccent),
            label: const Text('Upload now',
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
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

  List<Widget> _renderIncidentPins() {
    // Only show pins that mathematically reside exactly on the selected floor
    final floorIncidents = widget.incidents.where((i) => i.affectedZone.contains('(Floor $_currentFloor)')).toList();
    
    return floorIncidents.map((incident) {
      final roomInt =
          int.tryParse(incident.affectedZone.replaceAll(RegExp(r'[^0-9]'), '')) ??
              101;
      final double pseudoX = (roomInt * 17.5) % 600 + 80;
      final double pseudoY = (roomInt * 23.3) % 380 + 80;

      Color severityColor;
      switch (incident.severity) {
        case 5:
          severityColor = Colors.red;
          break;
        case 4:
          severityColor = Colors.orange;
          break;
        case 3:
          severityColor = Colors.amber;
          break;
        case 2:
          severityColor = Colors.lightBlueAccent;
          break;
        default:
          severityColor = Colors.grey;
          break;
      }

      return Positioned(
        left: pseudoX,
        top: pseudoY,
        child: _HoverablePin(
          incident: incident,
          color: severityColor,
        ),
      );
    }).toList();
  }
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
