import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:flutter/material.dart';

/// Where a device's dot sits around the circle. BLE gives no direction, so
/// the angle only spreads dots apart; it is derived from the device id so
/// a dot stays put while the list changes (FNV-1a, stable across runs).
double radarAngleFor(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return (hash / 0x100000000) * 2 * math.pi;
}

/// Distance of a device's dot from the centre, as a fraction of the radius.
/// Stronger signal = closer to the centre.
double radarDistanceFor(int rssi) {
  final ratio = ((rssi + 100).clamp(0, 70) / 70.0).clamp(0.1, 0.9);
  return 1.0 - ratio;
}

/// Position of a device's dot in a chart of [size].
Offset radarPositionFor(ScannedDeviceModel device, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final distance =
      math.min(size.width, size.height) / 2 * radarDistanceFor(device.rssi);
  final angle = radarAngleFor(device.id);
  return center + Offset(math.cos(angle), math.sin(angle)) * distance;
}

class MultiTargetRadarPainter extends CustomPainter {
  MultiTargetRadarPainter({
    required this.sweepAngle,
    required this.devices,
    required this.gridColor,
    required this.labelColor,
    required this.labelBackground,
    required this.accent,
  });

  final double sweepAngle;
  final List<ScannedDeviceModel> devices;
  final Color gridColor;
  final Color labelColor;
  final Color labelBackground;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
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
            color: labelColor,
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
        colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.0)],
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
    canvas.drawCircle(center, 5, Paint()..color = accent);

    // Plot ALL discovered devices as interactive target dots on radar map
    for (final device in devices) {
      final color = signalColorFor(device.rssi);
      final blipPos = radarPositionFor(device, size);
      final blipX = blipPos.dx;
      final blipY = blipPos.dy;

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
            backgroundColor: labelBackground.withValues(alpha: 0.9),
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
        oldDelegate.devices != devices ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelBackground != labelBackground;
  }
}
