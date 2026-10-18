import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/widgets/dashboard_scan_status.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Empty-room baseline: a prominent call to action until it is taken, then a
/// compact "Baseline 09:12 · 7 trusted" line with a Retake option. Disabled
/// (with the reason) while the scanner can't actually see devices.
class RoomBaselineCard extends HookConsumerWidget {
  const RoomBaselineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The scanner's view of trust also covers a baseline that could only be
    // kept in memory because saving it to the session failed.
    final (hasBaseline, baselineAt, trustedCount, status) = ref.watch(
      scannerViewModelProvider.select(
        (s) => (
          s.hasBaseline,
          s.baselineAt,
          s.trustedIds.length,
          dashboardScanStatusOf(s),
        ),
      ),
    );
    final isTaking = useState(false);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isLive = status == DashboardScanStatus.live;
    final blockedReason = switch (status) {
      DashboardScanStatus.live => null,
      DashboardScanStatus.bluetoothOff => 'status_bluetooth_off'.tr(),
      DashboardScanStatus.locationOff => 'dash_status_location_off'.tr(),
      DashboardScanStatus.failed => 'status_scan_failed'.tr(),
      DashboardScanStatus.stopped => 'status_scan_stopped'.tr(),
    };

    Future<void> takeBaseline() async {
      final visible = ref.read(scannerViewModelProvider).devices.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.fact_check_outlined),
          title: Text(
            hasBaseline
                ? 'dash_baseline_retake_title'.tr()
                : 'dash_baseline_confirm_title'.tr(),
          ),
          content: Text(
            hasBaseline
                ? 'dash_baseline_retake_message'.tr(args: {'count': '$visible'})
                : 'dash_baseline_confirm_message'.tr(
                    args: {'count': '$visible'},
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('dash_baseline_take'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      isTaking.value = true;
      String message;
      var failed = false;
      try {
        final count = await ref
            .read(scannerViewModelProvider.notifier)
            .takeBaseline();
        message = 'dash_baseline_result'.tr(args: {'count': '$count'});
      } catch (_) {
        failed = true;
        message = 'dash_baseline_failed'.tr();
      } finally {
        if (context.mounted) isTaking.value = false;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: failed ? colors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final onTake = isLive && !isTaking.value ? takeBaseline : null;

    if (hasBaseline) {
      final time = baselineAt == null
          ? '—'
          : TimeOfDay.fromDateTime(baselineAt).format(context);
      return Container(
        padding: EdgeInsetsDirectional.only(
          start: AppDimens.spacingSmall,
          end: 4.w,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, size: 18.w, color: AppColors.success),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'dash_baseline_done'.tr(
                  args: {'time': time, 'count': '$trustedCount'},
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            Tooltip(
              message: 'dash_baseline_needs_live'.tr(
                args: {'reason': blockedReason ?? ''},
              ),
              // Explains why Retake is disabled; silent while it works.
              triggerMode: blockedReason == null
                  ? TooltipTriggerMode.manual
                  : TooltipTriggerMode.tap,
              child: TextButton.icon(
                onPressed: onTake,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
                icon: isTaking.value
                    ? SizedBox.square(
                        dimension: 14.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, size: 16.w),
                label: Text('dash_baseline_retake'.tr()),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Color.alphaBlend(
        colors.primary.withValues(alpha: 0.08),
        colors.surfaceContainerLow,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(
          color: colors.primary.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fact_check_outlined,
                    size: 22.w,
                    color: colors.primary,
                  ),
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Text(
                    'dash_baseline_title'.tr(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimens.spacingSmall),
            Text(
              'dash_baseline_message'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTake,
                icon: isTaking.value
                    ? SizedBox.square(
                        dimension: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.radar_rounded),
                label: Text('dash_baseline_take'.tr()),
              ),
            ),
            if (blockedReason != null) ...[
              SizedBox(height: AppDimens.spacingExtraSmall),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14.w,
                    color: dashboardWarningColor(context),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'dash_baseline_needs_live'.tr(
                        args: {'reason': blockedReason},
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: dashboardWarningColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
