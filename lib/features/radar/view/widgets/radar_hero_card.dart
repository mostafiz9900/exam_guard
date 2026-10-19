import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_sizes.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_colors.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_gauge.dart';

/// Above-the-fold hero: closeness gauge, warmer/colder pill, one hint line
/// and "best so far" with reset.
class RadarHeroCard extends StatelessWidget {
  const RadarHeroCard({
    super.key,
    required this.gaugeDiameter,
    required this.mode,
    required this.closeness,
    required this.smoothedRssi,
    required this.distanceText,
    required this.trend,
    required this.peakCloseness,
    required this.peakRssi,
    required this.hint,
    required this.lastHeardText,
    required this.onResetPeak,
  });

  final double gaugeDiameter;
  final GaugeMode mode;

  /// Live value, or the last value while the signal is lost.
  final int? closeness;
  final double? smoothedRssi;
  final String distanceText;
  final ProximityTrend trend;
  final int? peakCloseness;
  final double? peakRssi;

  /// One short line under the pill; null hides it.
  final String? hint;

  /// "Last heard 7 s ago" while the signal is lost.
  final String? lastHeardText;
  final VoidCallback onResetPeak;

  static IconData trendIcon(ProximityTrend trend) => switch (trend) {
    ProximityTrend.approaching => Icons.trending_up_rounded,
    ProximityTrend.receding => Icons.trending_down_rounded,
    ProximityTrend.stationary => Icons.pan_tool_alt_rounded,
  };

  static String trendKey(ProximityTrend trend) => switch (trend) {
    ProximityTrend.approaching => 'radar_finder_warmer',
    ProximityTrend.receding => 'radar_finder_colder',
    ProximityTrend.stationary => 'radar_finder_steady',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLive = mode == GaugeMode.live;

    final Widget? pill = switch (mode) {
      GaugeMode.live => _Pill(
        key: ValueKey(trend),
        icon: trendIcon(trend),
        label: trendKey(trend).tr(),
        color: trendColor(trend, colors),
      ),
      GaugeMode.lost when lastHeardText != null => _Pill(
        key: const ValueKey('lost'),
        icon: Icons.history_rounded,
        label: lastHeardText!,
        color: colors.error,
      ),
      _ => null,
    };

    return Card(
      key: const Key('radar_hero'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spacingMedium,
          AppDimens.spacingSmall,
          AppDimens.spacingMedium,
          AppDimens.spacingSmall,
        ),
        child: Column(
          children: [
            ClosenessGauge(
              diameter: gaugeDiameter,
              mode: mode,
              closeness: closeness,
              peak: peakCloseness,
              centerBuilder: (context, value) => isLive
                  ? _LiveCenter(
                      value: value,
                      diameter: gaugeDiameter,
                      rssiText:
                          '${smoothedRssi == null ? '--' : smoothedRssi!.round()} dBm',
                      distanceText: distanceText,
                    )
                  : _StatusCenter(mode: mode, diameter: gaugeDiameter),
            ),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: pill ?? const SizedBox.shrink(key: ValueKey('none')),
            ),
            if (hint != null) ...[
              SizedBox(height: AppDimens.spacingExtraSmall),
              Text(
                hint!,
                key: const Key('radar_hint'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: AppDimens.spacingSmall),
            _BestSoFar(
              peak: peakCloseness,
              peakRssi: peakRssi,
              onReset: onResetPeak,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCenter extends StatelessWidget {
  const _LiveCenter({
    required this.value,
    required this.diameter,
    required this.rssiText,
    required this.distanceText,
  });

  final double value;
  final double diameter;
  final String rssiText;
  final String distanceText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final percent = (value * 100).round();
    final readout = theme.textTheme.titleSmall?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'radar_finder_closeness'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              '$percent%',
              key: const Key('radar_percent'),
              style: TextStyle(
                fontSize: diameter * 0.23,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1,
                color: readableInk(context, closenessColorAt(value)),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rssiText, textDirection: TextDirection.ltr, style: readout),
              Text('  ·  ', style: readout),
              Text(distanceText, style: readout),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCenter extends StatelessWidget {
  const _StatusCenter({required this.mode, required this.diameter});

  final GaugeMode mode;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (IconData icon, String label, Color color) = switch (mode) {
      GaugeMode.acquiring => (
        Icons.sensors_rounded,
        'radar_acquiring_center'.tr(),
        colors.primary,
      ),
      GaugeMode.lost => (
        Icons.signal_cellular_connected_no_internet_0_bar_rounded,
        'radar_signal_lost_short'.tr(),
        colors.error,
      ),
      _ => (
        Icons.sensors_off_rounded,
        'radar_not_measuring'.tr(),
        colors.outline,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: diameter * 0.16, color: color),
        SizedBox(height: diameter * 0.03),
        Flexible(
          child: Text(
            label,
            key: const Key('radar_status_center'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: readableInk(context, color),
            ),
          ),
        ),
        Text(
          '-- dBm',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = readableInk(context, color);
    return Container(
      constraints: BoxConstraints(minHeight: 40.rc),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMedium,
        vertical: 6.rc,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(40.rc),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ink, size: 22.rc),
          SizedBox(width: 8.rc),
          Flexible(
            child: Text(
              label,
              key: const Key('radar_pill'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestSoFar extends StatelessWidget {
  const _BestSoFar({
    required this.peak,
    required this.peakRssi,
    required this.onReset,
  });

  final int? peak;
  final double? peakRssi;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final value = peak;
    return Container(
      padding: EdgeInsetsDirectional.only(start: AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, size: 20.rc, color: colors.primary),
          SizedBox(width: 8.rc),
          Expanded(
            child: Text(
              value == null
                  ? 'radar_finder_peak_none'.tr()
                  : 'radar_finder_peak'.tr(
                      args: {
                        'percent': '$value',
                        'rssi': '${peakRssi?.round() ?? '--'}',
                      },
                    ),
              key: const Key('radar_best'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('radar_reset_peak'),
            tooltip: 'radar_finder_peak_reset'.tr(),
            onPressed: value == null ? null : onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}
