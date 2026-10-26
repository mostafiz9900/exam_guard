import 'package:flutter/material.dart';

import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/scanner/model/presence_tracker.dart';

/// Signal strength of one device over time: a line through its samples,
/// broken where it went silent, on shaded bands for when it was present.
/// Higher = stronger = closer. Used by the device details sheet and the
/// exam report.
class SignalTimelineChart extends StatelessWidget {
  const SignalTimelineChart({
    super.key,
    required this.samples,
    required this.intervals,
    required this.from,
    required this.to,
    this.height = 110,
  });

  final List<SignalSample> samples;
  final List<PresenceInterval> intervals;
  final DateTime from;
  final DateTime to;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _ChartPainter(
              samples: samples,
              intervals: intervals,
              from: from,
              to: to,
              line: colors.primary,
              band: colors.primary.withValues(alpha: 0.10),
              grid: colors.outlineVariant,
              label: label ?? const TextStyle(fontSize: 10),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(AppDateFormat.clock(from), style: label),
            const Spacer(),
            Text(AppDateFormat.clock(to), style: label),
          ],
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.samples,
    required this.intervals,
    required this.from,
    required this.to,
    required this.line,
    required this.band,
    required this.grid,
    required this.label,
  });

  final List<SignalSample> samples;
  final List<PresenceInterval> intervals;
  final DateTime from;
  final DateTime to;
  final Color line;
  final Color band;
  final Color grid;
  final TextStyle label;

  static const double _minDbm = -100;
  static const double _maxDbm = -30;

  @override
  void paint(Canvas canvas, Size size) {
    final span = to.difference(from).inMilliseconds;
    if (span <= 0) return;
    double x(DateTime t) =>
        (t.difference(from).inMilliseconds / span).clamp(0.0, 1.0) * size.width;
    double y(int dbm) =>
        (1 - ((dbm - _minDbm) / (_maxDbm - _minDbm)).clamp(0.0, 1.0)) *
        size.height;

    // Reference lines: "near" (-65 dBm) and "in range" (-88 dBm).
    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final level in const [-65, -88]) {
      final yy = y(level);
      for (var xx = 0.0; xx < size.width; xx += 8) {
        canvas.drawLine(Offset(xx, yy), Offset(xx + 4, yy), dash);
      }
      final tp = TextPainter(
        text: TextSpan(text: '$level', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, yy - tp.height));
    }

    // Presence bands.
    final bandPaint = Paint()..color = band;
    for (final i in intervals) {
      final left = x(i.start);
      final right = x(i.end).clamp(left + 2, size.width);
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), bandPaint);
    }

    // Signal line, broken across absences.
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = line;
    Path? path;
    SignalSample? prev;
    for (final s in samples) {
      if (s.at.isBefore(from) || s.at.isAfter(to)) continue;
      final p = Offset(x(s.at), y(s.rssi));
      final broken =
          prev == null || s.at.difference(prev.at) >= PresenceTracker.goneAfter;
      if (broken) {
        if (path != null) canvas.drawPath(path, stroke);
        path = Path()..moveTo(p.dx, p.dy);
        canvas.drawCircle(p, 2, dot);
      } else {
        path!.lineTo(p.dx, p.dy);
      }
      prev = s;
    }
    if (path != null) canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.samples != samples ||
      old.intervals != intervals ||
      old.from != from ||
      old.to != to ||
      old.line != line;
}
