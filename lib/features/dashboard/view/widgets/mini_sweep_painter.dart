import 'dart:math' as math;

import 'package:flutter/material.dart';

class MiniSweepPainter extends CustomPainter {
  MiniSweepPainter({required this.angle, required this.color});
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MiniSweepPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
