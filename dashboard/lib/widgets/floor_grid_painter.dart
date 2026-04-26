import 'package:flutter/material.dart';

class _FloorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A4A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Outer walls
    final wallPaint = Paint()
      ..color = const Color(0xFF4A4A6A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.04, size.height * 0.05, size.width * 0.92, size.height * 0.90),
      wallPaint,
    );

    // Corridor line (horizontal midpoint)
    final corridorPaint = Paint()
      ..color = const Color(0xFF3A3A5A)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.04, size.height * 0.50),
      Offset(size.width * 0.96, size.height * 0.50),
      corridorPaint,
    );
    // Corridor vertical
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.05),
      Offset(size.width * 0.50, size.height * 0.95),
      corridorPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
