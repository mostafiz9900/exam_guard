import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';

/// Green only while hall data is live; grey/red otherwise, never "all
/// clear" while not linked.
class HallStatusBanner extends StatelessWidget {
  const HallStatusBanner({super.key, required this.state});

  final HallState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final room = {'room': state.room};
    final (IconData icon, Color color, String text) = switch (state.status) {
      HallLinkStatus.hosting => (
        Icons.hub_rounded,
        AppColors.success,
        'hall_status_hosting'.tr(args: room),
      ),
      HallLinkStatus.connected => (
        Icons.link_rounded,
        AppColors.success,
        'hall_status_connected'.tr(args: room),
      ),
      HallLinkStatus.starting || HallLinkStatus.connecting => (
        Icons.sync_rounded,
        colors.primary,
        'hall_status_connecting'.tr(),
      ),
      HallLinkStatus.reconnecting => (
        Icons.link_off_rounded,
        colors.error,
        'hall_status_reconnecting'.tr(),
      ),
      HallLinkStatus.failed || HallLinkStatus.idle => (
        Icons.link_off_rounded,
        colors.outline,
        'hall_status_off'.tr(),
      ),
    };
    final error = state.errorKey;
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24.w),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (error != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    error.tr(),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
