import 'package:flutter/material.dart';

class VenueMap extends StatefulWidget {
  const VenueMap({super.key});

  @override
  State<VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<VenueMap> {
  final TransformationController _controller = TransformationController();

  void _zoomIn() {
    _controller.value = _controller.value.scaled(1.2);
  }

  void _zoomOut() {
    _controller.value = _controller.value.scaled(0.8);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C3E), // Darker map mock background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          // Mock building plan background
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 4.0,
              child: Stack(
                children: [
                  const Center(
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.map, size: 800, color: Colors.white),
                    ),
                  ),
                  
                  // Mock Incident Pins
                  Positioned(
                    top: 250,
                    left: 300,
                    child: _buildPin(Colors.redAccent),
                  ),
                  Positioned(
                    top: 400,
                    right: 280,
                    child: _buildPin(Colors.amber),
                  ),
                ],
              ),
            ),
          ),
          
          // Map Controls overlay
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomInLoc',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOutLoc',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin(Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 4,
              )
            ]
          ),
          child: const Icon(Icons.warning, color: Colors.white, size: 20),
        ),
        Container(
          width: 4,
          height: 16,
          color: color,
        )
      ],
    );
  }
}
