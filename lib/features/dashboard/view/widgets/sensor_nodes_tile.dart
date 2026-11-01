import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';

/// ESP32 sensor nodes at a glance: none yet (invites setting one up),
/// live with what they hear, or — red — a node that went offline.
class SensorNodesTile extends ConsumerWidget {
  const SensorNodesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hallViewModelProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final live = [
      for (final m in state.members)
        if (m.kind == HallMemberKind.node) m.id,
    ];
    final offline = state.offlineNodes;
    final heard = state.remoteDevices
        .where((d) => live.contains(d.sourceId))
        .length;

    final (
      IconData icon,
      Color color,
      String title,
      String text,
    ) = offline.isNotEmpty
        ? (
            Icons.sensors_off_rounded,
            colors.error,
            'hall_nodes_offline_title'.tr(),
            offline.map((n) => n.member.name).join(', '),
          )
        : live.isNotEmpty
        ? (
            Icons.sensors_rounded,
            AppColors.success,
            'dash_nodes_title'.tr(),
            'dash_nodes_live'.tr(
              args: {'count': '${live.length}', 'devices': '$heard'},
            ),
          )
        : (
            Icons.sensors_rounded,
            colors.tertiary,
            'dash_nodes_title'.tr(),
            'dash_nodes_none'.tr(),
          );

    Widget pill(String label, Color c) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: c,
          fontWeight: FontWeight.bold,
          fontSize: 10.sp,
        ),
      ),
    );

    return Card(
      key: const Key('dash_nodes_tile'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        onTap: () => context.pushTo(AppRoute.nodes),
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingSmall),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20.w),
              ),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: offline.isNotEmpty ? colors.error : null,
                      ),
                    ),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 10.sp,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (live.isNotEmpty || offline.isNotEmpty) ...[
                SizedBox(width: 6.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (live.isNotEmpty)
                      pill(
                        'dash_nodes_pill_live'.tr(
                          args: {'count': '${live.length}'},
                        ),
                        AppColors.success,
                      ),
                    if (live.isNotEmpty && offline.isNotEmpty)
                      SizedBox(height: 4.h),
                    if (offline.isNotEmpty)
                      pill(
                        'dash_nodes_pill_offline'.tr(
                          args: {'count': '${offline.length}'},
                        ),
                        colors.error,
                      ),
                  ],
                ),
              ] else
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 6.w),
                  child: pill('dash_nodes_setup'.tr(), color),
                ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
