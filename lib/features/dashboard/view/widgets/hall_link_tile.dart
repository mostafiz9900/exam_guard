import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view/widgets/hall_alerts_card.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';

/// Hall link at a glance: off, live (members / nodes / shared devices), lost,
/// or — most important — the newest alert from another invigilator.
class HallLinkTile extends ConsumerWidget {
  const HallLinkTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hallViewModelProvider);
    final colors = Theme.of(context).colorScheme;
    final pending = state.pendingAlerts;

    final (
      IconData icon,
      Color color,
      String title,
      String text,
    ) = pending.isNotEmpty
        ? (
            Icons.warning_amber_rounded,
            colors.error,
            'dash_hall_alerts'.tr(args: {'count': '${pending.length}'}),
            remoteAlertText(pending.first),
          )
        : state.offlineNodes.isNotEmpty
        ? (
            Icons.sensors_off_rounded,
            colors.error,
            'hall_nodes_offline_title'.tr(),
            state.offlineNodes.map((n) => n.member.name).join(', '),
          )
        : !state.isActive
        ? (
            Icons.hub_outlined,
            colors.onSurfaceVariant,
            'dash_hall_title'.tr(),
            'dash_hall_off'.tr(),
          )
        : state.status.isLive
        ? (
            Icons.hub_rounded,
            AppColors.success,
            'dash_hall_title'.tr(),
            'dash_hall_live'.tr(
              args: {
                'members':
                    '${state.members.where((m) => m.kind == HallMemberKind.phone).length}',
                'nodes': '${state.nodeCount}',
                'devices': '${state.remoteDevices.length}',
              },
            ),
          )
        : (
            Icons.link_off_rounded,
            colors.error,
            'dash_hall_title'.tr(),
            'dash_hall_not_live'.tr(),
          );

    return Card(
      key: const Key('dash_hall_tile'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        onTap: () => context.pushTo(AppRoute.hall),
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingSmall),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22.w),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: color == colors.error ? colors.error : null,
                      ),
                    ),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10.sp,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
