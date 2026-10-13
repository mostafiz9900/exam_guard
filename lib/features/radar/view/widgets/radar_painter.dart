import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.sweepAngle,
    required this.rssi,
    required this.distanceMeters,
    required this.threatColor,
    required this.trend,
  });

  final double sweepAngle;
  final int rssi;
  final double distanceMeters;
  final Color threatColor;
  final ProximityTrend trend;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    final radii = [
      maxRadius * 0.25,
      maxRadius * 0.50,
      maxRadius * 0.75,
      maxRadius,
    ];

    final distanceLabels = ['1.5m', '3.0m', '4.5m', '6.0m+'];

    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];
      canvas.drawCircle(center, r, ringPaint);

      // Draw Distance Meter Labels on the radar map axis
      final textPainter = TextPainter(
        text: TextSpan(
          text: distanceLabels[i],
          style: TextStyle(
            color: Colors.teal.shade700,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 4, center.dy - r - 12));
    }

    // Draw crosshair axes
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Draw rotating radar sweep gradient arc
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          threatColor.withValues(alpha: 0.4),
          threatColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();

    // 5. Draw Dynamic Animated Red Target Dot & Tracking Laser Line
    final blipRatio = ((rssi + 100).clamp(0, 70) / 70.0).clamp(0.1, 0.9);
    final blipDistance = maxRadius * (1.0 - blipRatio);

    // Dynamically sweep blip position along with radar beam
    final blipAngle = sweepAngle - 0.35;
    final blipX = center.dx + blipDistance * math.cos(blipAngle);
    final blipY = center.dy + blipDistance * math.sin(blipAngle);

    final redColor = threatColor;

    // Draw animated connecting laser line from center to red target dot
    canvas.drawLine(
      center,
      Offset(blipX, blipY),
      Paint()
        ..color = redColor.withValues(alpha: 0.6)
        ..strokeWidth = 2.0,
    );

    // Outer pulsing red glow rings
    canvas.drawCircle(
      Offset(blipX, blipY),
      22.0,
      Paint()
        ..color = redColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(blipX, blipY),
      14.0,
      Paint()
        ..color = redColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Solid Inner Red Dot
    canvas.drawCircle(
      Offset(blipX, blipY),
      8.0,
      Paint()
        ..color = redColor
        ..style = PaintingStyle.fill,
    );

    // Center White Pin-point Dot
    canvas.drawCircle(Offset(blipX, blipY), 3.0, Paint()..color = Colors.white);

    // Prominent Red Target Distance Badge
    final blipTextPainter = TextPainter(
      text: TextSpan(
        text: ' 🔴 TARGET THREAT (${distanceMeters}m) ',
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Color(0xFFEF4444),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    blipTextPainter.layout();
    blipTextPainter.paint(canvas, Offset(blipX + 12, blipY - 12));
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.rssi != rssi ||
        oldDelegate.distanceMeters != distanceMeters ||
        oldDelegate.trend != trend;
  }
}
