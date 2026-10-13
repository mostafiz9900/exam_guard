import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter/material.dart';

class MultiTargetRadarPainter extends CustomPainter {
  MultiTargetRadarPainter({required this.sweepAngle, required this.devices});

  final double sweepAngle;
  final List<ScannedDeviceModel> devices;

  Color _getThreatColor(int rssi) {
    if (rssi > -60) return const Color(0xFFEF4444); // Red Critical
    if (rssi > -75) return const Color(0xFFF97316); // Orange High
    if (rssi > -88) return const Color(0xFFF59E0B); // Yellow Medium
    return const Color(0xFF10B981); // Green Low
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final gridPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar distance rings
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

      final textPainter = TextPainter(
        text: TextSpan(
          text: distanceLabels[i],
          style: TextStyle(
            color: Colors.teal.shade700,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 4, center.dy - r - 10));
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

    // Draw 360° rotating radar sweep beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
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

    // Center Inspector Phone Icon Dot
    canvas.drawCircle(center, 5, Paint()..color = AppColors.primary);

    // Plot ALL discovered devices as interactive target dots on radar map
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      final color = _getThreatColor(device.rssi);

      final blipRatio = ((device.rssi + 100).clamp(0, 70) / 70.0).clamp(
        0.1,
        0.9,
      );
      final blipDistance = maxRadius * (1.0 - blipRatio);

      // Distribute device dots evenly around 360° radar plane
      final blipAngle =
          -math.pi / 2 + (i * 2 * math.pi / math.max(1, devices.length));
      final blipX = center.dx + blipDistance * math.cos(blipAngle);
      final blipY = center.dy + blipDistance * math.sin(blipAngle);
      final blipPos = Offset(blipX, blipY);

      // Draw connecting line to center
      canvas.drawLine(
        center,
        blipPos,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1.0,
      );

      // Outer glowing pulse circle
      canvas.drawCircle(
        blipPos,
        12.0,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );

      // Inner target dot
      canvas.drawCircle(
        blipPos,
        6.0,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Device name compact label tag
      final namePainter = TextPainter(
        text: TextSpan(
          text: device.displayName.substring(
            0,
            math.min(7, device.displayName.length),
          ),
          style: TextStyle(
            color: color,
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            backgroundColor: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(blipX + 6, blipY - 6));
    }
  }

  @override
  bool shouldRepaint(covariant MultiTargetRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.devices != devices;
  }
}

/// Ultra-Professional Device List Card with Signal Bars, Vendor Badge & Quick Actions
