import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/rf_detector/model/rf_threat_level.dart';
import 'package:exam_guard/features/scanner/view/distance_text.dart';

/// Zone colours shared by the dial and the history chart.
abstract final class RfColors {
  static const Color quiet = Color(0xFF10B981);
  static const Color moderate = Color(0xFFF59E0B);
  static const Color strong = Color(0xFFEF4444);

  static Color of(RfThreatLevel level) => switch (level) {
    RfThreatLevel.quiet => quiet,
    RfThreatLevel.moderate => moderate,
    RfThreatLevel.strong => strong,
  };
}

/// Semicircular "how close" dial: far on the left, close on the right,
/// green / amber / red zones, a marker on the current reading. The centre
/// says it in words with an approximate distance; dBm is the small print.
class RfDial extends StatelessWidget {
  const RfDial({
    super.key,
    required this.dbm,
    required this.level,
    required this.isMeasuring,
  });

  /// Strongest signal now; null when nothing is heard.
  final double? dbm;
  final RfThreatLevel level;
  final bool isMeasuring;

  static const double minDbm = -100;
  static const double maxDbm = -30;

  static double fractionOf(double dbm) =>
      ((dbm - minDbm) / (maxDbm - minDbm)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = isMeasuring ? RfColors.of(level) : colors.outline;
    final reading = isMeasuring ? dbm : null;
    final target = reading == null ? 0.0 : fractionOf(reading);
    final word = !isMeasuring
        ? 'rf_word_off'.tr()
        : 'rf_word_${level.name}'.tr();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);

    return LayoutBuilder(
      builder: (context, c) {
        final width = math.min(c.maxWidth, 300.0);
        return Center(
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                SizedBox(
                  height: width * 0.56,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: target),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: _DialPainter(
                        value: value,
                        hasReading: reading != null,
                        color: color,
                        track: colors.surfaceContainerHighest,
                        isMeasuring: isMeasuring,
                      ),
                      child: Align(
                        alignment: const Alignment(0, 0.75),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              word,
                              key: const Key('rf_dial_word'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            if (isMeasuring && reading != null)
                              Text(
                                'dist_away'.tr(
                                  args: {
                                    'distance': approxDistanceText(reading),
                                  },
                                ),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  reading == null
                                      ? '--'
                                      : reading.round().toString(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  'dBm',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Row(
                    children: [
                      Text(
                        'rf_scale_far'.tr(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'rf_scale_close'.tr(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.value,
    required this.hasReading,
    required this.color,
    required this.track,
    required this.isMeasuring,
  });

  final double value;
  final bool hasReading;
  final Color color;
  final Color track;
  final bool isMeasuring;

  /// Zone boundaries (-70 / -50 dBm) as dial fractions.
  static final double _amberFrom = RfDial.fractionOf(-70);
  static final double _redFrom = RfDial.fractionOf(-50);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    double angle(double f) => math.pi + f * math.pi;

    void arc(double from, double to, Color c) => canvas.drawArc(
      rect,
      angle(from),
      (to - from) * math.pi,
      false,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );

    // Zones, faint; grey while not measuring.
    if (isMeasuring) {
      arc(0, _amberFrom, RfColors.quiet.withValues(alpha: 0.22));
      arc(_amberFrom, _redFrom, RfColors.moderate.withValues(alpha: 0.22));
      arc(_redFrom, 1, RfColors.strong.withValues(alpha: 0.22));
    } else {
      arc(0, 1, track);
    }
    if (!hasReading) return;

    // Filled up to the reading in its zone colour.
    arc(0, value, color);

    // Marker.
    final a = angle(value);
    final p = center + Offset(math.cos(a), math.sin(a)) * radius;
    canvas
      ..drawCircle(p, stroke * 0.62, Paint()..color = Colors.white)
      ..drawCircle(
        p,
        stroke * 0.62,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.color != color ||
      old.hasReading != hasReading ||
      old.isMeasuring != isMeasuring;
}
