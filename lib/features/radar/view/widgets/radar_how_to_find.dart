import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_sizes.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/view/widgets/direction_step_item.dart';

/// Collapsible "How to find it" guide: tips, the three steps and the
/// honesty note. Collapsed by default so the gauge stays above the fold.
class RadarHowToFind extends StatelessWidget {
  const RadarHowToFind({super.key});

  static String _trim(double m) =>
      m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
    );
    return Card(
      key: const Key('radar_how_to_find'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: shape.copyWith(
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: shape,
          collapsedShape: shape,
          tilePadding: EdgeInsets.symmetric(horizontal: AppDimens.spacingSmall),
          childrenPadding: EdgeInsets.fromLTRB(
            AppDimens.spacingSmall,
            0,
            AppDimens.spacingSmall,
            AppDimens.spacingSmall,
          ),
          leading: Icon(Icons.explore_rounded, color: colors.primary),
          title: Text(
            'radar_how_to_find'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          subtitle: Text(
            'radar_guide_subtitle'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          children: [
            Container(
              padding: EdgeInsets.all(AppDimens.spacingSmall),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18.rc,
                    color: colors.primary,
                  ),
                  SizedBox(width: 8.rc),
                  Expanded(
                    child: Text(
                      'radar_finder_tips'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DirectionStepItem(
              stepNumber: '1',
              title: 'radar_guide_step1_title'.tr(),
              description: 'radar_guide_step1_text'.tr(),
              icon: Icons.directions_walk_rounded,
            ),
            DirectionStepItem(
              stepNumber: '2',
              title: 'radar_guide_step2_title'.tr(),
              description: 'radar_guide_step2_text'.tr(
                args: {
                  'closer': ProximityTrend.approaching.labelKey.tr(),
                  'away': ProximityTrend.receding.labelKey.tr(),
                  'steady': ProximityTrend.stationary.labelKey.tr(),
                },
              ),
              icon: Icons.alt_route_rounded,
            ),
            DirectionStepItem(
              stepNumber: '3',
              title: 'radar_guide_step3_title'.tr(),
              description: 'radar_guide_step3_text'.tr(
                args: {
                  'critical': ThreatLevel.critical.labelKey.tr(),
                  'meters': _trim(ThreatLevel.criticalWithin),
                },
              ),
              icon: Icons.pin_drop_rounded,
            ),
            Text(
              'radar_finder_honest'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
