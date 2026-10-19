import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_sizes.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_colors.dart';

/// Honest replacement for the old radar rings: four distance bands (far →
/// near) with the current one lit. Distance only — RSSI has no bearing.
class DistanceBandCard extends StatelessWidget {
  const DistanceBandCard({super.key, required this.level});

  /// Current band; null while not measuring (nothing is lit).
  final ThreatLevel? level;

  /// Far → near, matching the gauge's cold → hot direction.
  static const List<ThreatLevel> bands = [
    ThreatLevel.low,
    ThreatLevel.medium,
    ThreatLevel.high,
    ThreatLevel.critical,
  ];

  static String _trim(double m) =>
      m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);

  static String bandLabel(ThreatLevel band) => switch (band) {
    ThreatLevel.critical => 'radar_band_within'.tr(
      args: {'meters': _trim(ThreatLevel.criticalWithin)},
    ),
    ThreatLevel.high => 'radar_band_range'.tr(
      args: {
        'from': _trim(ThreatLevel.criticalWithin),
        'to': _trim(ThreatLevel.highWithin),
      },
    ),
    ThreatLevel.medium => 'radar_band_range'.tr(
      args: {
        'from': _trim(ThreatLevel.highWithin),
        'to': _trim(ThreatLevel.mediumWithin),
      },
    ),
    ThreatLevel.low => 'radar_distance_far'.tr(
      args: {'meters': _trim(ThreatLevel.mediumWithin)},
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = level;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return Card(
      key: const Key('radar_distance_band'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.rc,
              runSpacing: 2.rc,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(end: 6.rc),
                          child: Icon(
                            Icons.social_distance_rounded,
                            size: 18.rc,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextSpan(text: 'radar_distance_band_title'.tr()),
                    ],
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (current != null)
                  Text(
                    current.labelKey.tr(),
                    key: const Key('radar_band_label'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: readableInk(context, threatColor(current)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.rc),
            Row(
              children: [
                for (var i = 0; i < bands.length; i++) ...[
                  if (i > 0) SizedBox(width: 4.rc),
                  Expanded(
                    child: _Segment(
                      label: bandLabel(bands[i]),
                      color: threatColor(bands[i]),
                      isActive: bands[i] == current,
                      duration: duration,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 6.rc),
            Text(
              'radar_distance_only'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.color,
    required this.isActive,
    required this.duration,
  });

  final String label;
  final Color color;
  final bool isActive;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedContainer(
          duration: duration,
          height: isActive ? 10.rc : 6.rc,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(6.rc),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(height: 4.rc),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isActive
                ? readableInk(context, color)
                : colors.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
