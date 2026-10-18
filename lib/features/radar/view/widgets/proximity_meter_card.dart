import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';

/// Cold blue → hot red for a 0–100 closeness value.
Color closenessColor(int percent) {
  const stops = [
    Color(0xFF3B82F6), // blue
    Color(0xFF06B6D4), // cyan
    Color(0xFFF59E0B), // amber
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
  ];
  final t = (percent.clamp(0, 100) / 100) * (stops.length - 1);
  final i = t.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], t - i)!;
}

/// Big, glanceable hot/cold meter: closeness %, trend in large text and a
/// "best so far" marker on the bar.
class ProximityMeterCard extends StatelessWidget {
  const ProximityMeterCard({
    super.key,
    required this.closeness,
    required this.smoothedRssi,
    required this.peakCloseness,
    required this.peakRssi,
    required this.trend,
    required this.statusText,
    required this.onResetPeak,
  });

  /// Null while not measuring.
  final int? closeness;
  final double? smoothedRssi;
  final int? peakCloseness;
  final double? peakRssi;
  final ProximityTrend trend;

  /// Shown instead of the trend while not measuring (acquiring, lost, ...).
  final String? statusText;
  final VoidCallback onResetPeak;

  static String trendKey(ProximityTrend trend) => switch (trend) {
    ProximityTrend.approaching => 'radar_finder_warmer',
    ProximityTrend.receding => 'radar_finder_colder',
    ProximityTrend.stationary => 'radar_finder_steady',
  };

  static IconData _trendIcon(ProximityTrend trend) => switch (trend) {
    ProximityTrend.approaching => Icons.trending_up_rounded,
    ProximityTrend.receding => Icons.trending_down_rounded,
    ProximityTrend.stationary => Icons.pause_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final value = closeness;
    final color = value == null ? colors.outline : closenessColor(value);
    final peak = peakCloseness;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'radar_finder_closeness'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                value == null ? '--' : '$value%',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 72.sp,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.05,
                ),
              ),
            ),
            Text(
              smoothedRssi == null || value == null
                  ? '-- dBm'
                  : '${smoothedRssi!.round()} dBm',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12.h),
            _MeterBar(value: value, peak: peak, color: color),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (statusText == null) ...[
                  Icon(_trendIcon(trend), color: color, size: 30.w),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    statusText ?? trendKey(trend).tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusText == null ? color : colors.outline,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 18.w, color: colors.primary),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    peak == null
                        ? 'radar_finder_peak_none'.tr()
                        : 'radar_finder_peak'.tr(
                            args: {
                              'percent': '$peak',
                              'rssi': '${peakRssi?.round() ?? '--'}',
                            },
                          ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: TextButton.icon(
                    onPressed: peak == null ? null : onResetPeak,
                    icon: Icon(Icons.restart_alt_rounded, size: 18.w),
                    label: Text(
                      'radar_finder_peak_reset'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'radar_finder_honest'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({
    required this.value,
    required this.peak,
    required this.color,
  });

  final int? value;
  final int? peak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = 18.h;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fill = (value ?? 0) / 100;
        final peakValue = peak;
        return SizedBox(
          height: height + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(height),
                  child: Stack(
                    children: [
                      Container(color: colors.surfaceContainerHighest),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: width * fill,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              closenessColor(0),
                              closenessColor(value ?? 0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (peakValue != null)
                PositionedDirectional(
                  start: (width * peakValue / 100 - 2).clamp(0.0, width - 4),
                  top: 0,
                  width: 4,
                  height: height + 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
