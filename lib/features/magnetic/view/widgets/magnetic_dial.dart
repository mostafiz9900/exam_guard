import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';

/// Hazard colours shared by the dial, guidance card and chart.
abstract final class MagColors {
  static const Color normal = Color(0xFF10B981);
  static const Color elevated = Color(0xFFF59E0B);
  static const Color critical = Color(0xFFEF4444);
  static const Color strong = Color(0xFFB91C1C);

  static Color of(MagneticHazardLevel level) => switch (level) {
    MagneticHazardLevel.normal => normal,
    MagneticHazardLevel.elevated => elevated,
    MagneticHazardLevel.critical => critical,
    MagneticHazardLevel.strongSource => strong,
  };
}

/// "How much has the field changed from normal": a semicircle from no
/// change to 5×T, with the hazard zones (T, 2T, 4T). The centre says it in
/// words, then the change in μT, then the total field as small print.
class MagneticDial extends StatelessWidget {
  const MagneticDial({super.key, required this.state});

  final MagneticState state;

  /// Full scale as a multiple of the sensitivity threshold.
  static const double scale = 5;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final live = state.isLive;
    final t = state.sensitivity.threshold;
    final color = live ? MagColors.of(state.hazardLevel) : colors.outline;
    final fraction = live ? (state.change / (scale * t)).clamp(0.0, 1.0) : 0.0;
    final word = state.isSensorUnavailable
        ? 'mag_word_unavailable'.tr()
        : !state.isScanning
        ? 'mag_word_paused'.tr()
        : !live
        ? 'mag_word_waiting'.tr()
        : 'mag_word_${state.hazardLevel.name}'.tr();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

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
                    tween: Tween(end: fraction),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: MagneticDialPainter(
                        fraction: value,
                        color: color,
                        isLive: live,
                        track: colors.surfaceContainerHighest,
                      ),
                      child: Align(
                        alignment: const Alignment(0, 0.8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              word,
                              key: const Key('mag_dial_word'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              live
                                  ? 'mag_change'.tr(
                                      args: {
                                        'value': state.change.toStringAsFixed(
                                          0,
                                        ),
                                      },
                                    )
                                  : '--',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (live)
                              Text(
                                'mag_total'.tr(
                                  args: {
                                    'value': state.magnitude.toStringAsFixed(1),
                                  },
                                ),
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
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
                        'mag_scale_none'.tr(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'mag_scale_strong'.tr(),
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

class MagneticDialPainter extends CustomPainter {
  MagneticDialPainter({
    required this.fraction,
    required this.color,
    required this.isLive,
    required this.track,
  });

  /// Change from baseline as a share of the dial (0–1).
  final double fraction;
  final Color color;
  final bool isLive;
  final Color track;

  // Zone boundaries at T, 2T and 4T on a 5T dial.
  static const double _elevated = 1 / MagneticDial.scale;
  static const double _critical = 2 / MagneticDial.scale;
  static const double _strong = 4 / MagneticDial.scale;

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
        ..strokeWidth = stroke,
    );

    if (isLive) {
      arc(0, _elevated, MagColors.normal.withValues(alpha: 0.22));
      arc(_elevated, _critical, MagColors.elevated.withValues(alpha: 0.22));
      arc(_critical, _strong, MagColors.critical.withValues(alpha: 0.22));
      arc(_strong, 1, MagColors.strong.withValues(alpha: 0.22));
    } else {
      arc(0, 1, track);
      return;
    }
    if (fraction <= 0) return;
    arc(0, fraction, color);
    final a = angle(fraction);
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
  bool shouldRepaint(MagneticDialPainter old) =>
      old.fraction != fraction || old.color != color || old.isLive != isLive;
}
