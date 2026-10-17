import 'dart:math' as math;

import 'package:flutter/material.dart';

class MagneticGaugePainter extends CustomPainter {
  MagneticGaugePainter({
    required this.magnitude,
    required this.angle,
    required this.color,
    required this.trackColor,
  });

  final double magnitude;
  final double angle;
  final Color color;

  /// Background ring colour; pass a theme-derived colour.
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track ring
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 8, bgPaint);

    // Active magnitude arc
    final activeRatio = (magnitude / 180.0).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -math.pi / 2,
      2 * math.pi * activeRatio,
      false,
      activePaint,
    );

    // Rotating Needle indicator
    final needleLength = radius - 24;
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final endX = center.dx + needleLength * math.cos(angle);
    final endY = center.dy + needleLength * math.sin(angle);

    canvas.drawLine(center, Offset(endX, endY), needlePaint);
    canvas.drawCircle(center, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant MagneticGaugePainter oldDelegate) {
    return oldDelegate.magnitude != magnitude ||
        oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
