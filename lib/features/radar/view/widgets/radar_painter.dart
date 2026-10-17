import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Distance-only radar: rings are drawn on a linear metre scale and the
/// target is drawn as a ring at its estimated distance. RSSI carries no
/// bearing, so nothing on this view implies a direction.
class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.sweepAngle,
    required this.distanceMeters,
    required this.color,
    required this.badgeLabel,
    required this.gridColor,
    required this.labelColor,
    required this.badgeTextColor,
    required this.ringLabels,
    required this.note,
    required this.textDirection,
  });

  /// Outermost ring, in metres. Targets further away sit on this ring.
  static const double maxMeters = 8.0;
  static const List<double> ringMeters = [1.5, 3.5, 6.0, maxMeters];

  final double sweepAngle;

  /// Null while acquiring / no live signal: no target ring is drawn.
  final double? distanceMeters;
  final Color color;
  final String? badgeLabel;
  final Color gridColor;
  final Color labelColor;
  final Color badgeTextColor;

  /// Already-translated label for each of [ringMeters], in the same order.
  final List<String> ringLabels;

  /// Already-translated honesty note shown at the bottom edge.
  final String note;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    double radiusFor(double meters) =>
        maxRadius * (meters.clamp(0.0, maxMeters) / maxMeters);

    final ringPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < ringMeters.length; i++) {
      final r = radiusFor(ringMeters[i]);
      canvas.drawCircle(center, r, ringPaint);
      if (i >= ringLabels.length) continue;
      _paintText(
        canvas,
        ringLabels[i],
        Offset(center.dx + 4, center.dy - r + 2),
        TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
      );
    }

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

    // Decorative "listening" sweep; it does not indicate a bearing.
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
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

    // Target: a ring at the estimated distance (no direction known).
    final distance = distanceMeters;
    if (distance != null) {
      final r = math.max(radiusFor(distance), 6.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14,
      );
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final badge = badgeLabel;
      if (badge != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: ' $badge ',
            style: TextStyle(
              color: badgeTextColor,
              backgroundColor: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: textDirection,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: size.width);
        final dx = (center.dx - painter.width / 2)
            .clamp(0.0, math.max(0.0, size.width - painter.width))
            .toDouble();
        final dy = (center.dy - r - painter.height - 4)
            .clamp(0.0, math.max(0.0, size.height - painter.height))
            .toDouble();
        painter.paint(canvas, Offset(dx, dy));
      }
    }

    // Honesty note at the bottom edge.
    final notePainter = TextPainter(
      text: TextSpan(
        text: note,
        style: TextStyle(color: labelColor, fontSize: 9),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width);
    notePainter.paint(
      canvas,
      Offset(
        (size.width - notePainter.width) / 2,
        math.max(0.0, size.height - notePainter.height),
      ),
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.distanceMeters != distanceMeters ||
        oldDelegate.color != color ||
        oldDelegate.badgeLabel != badgeLabel ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.badgeTextColor != badgeTextColor ||
        oldDelegate.note != note ||
        oldDelegate.textDirection != textDirection ||
        !listEquals(oldDelegate.ringLabels, ringLabels);
  }
}
