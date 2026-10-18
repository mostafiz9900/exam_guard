import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/widgets/device_alerts_sheet.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Newest unacknowledged alert, or null.
NewDeviceAlert? latestUnacknowledged(List<NewDeviceAlert> alerts) {
  NewDeviceAlert? latest;
  for (final a in alerts) {
    if (a.acknowledged) continue;
    if (latest == null || !a.detectedAt.isBefore(latest.detectedAt)) {
      latest = a;
    }
  }
  return latest;
}

/// Red banner while devices that appeared after the baseline are
/// unacknowledged. Tapping it opens the alerts sheet.
class NewDeviceAlertBanner extends ConsumerWidget {
  const NewDeviceAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (count, latest) = ref.watch(
      scannerViewModelProvider.select(
        (s) => (s.unacknowledgedAlertCount, latestUnacknowledged(s.alerts)),
      ),
    );
    if (count <= 0 || latest == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = colors.onError;

    return Padding(
      padding: EdgeInsets.only(bottom: AppDimens.spacingMedium),
      child: Material(
        color: colors.error,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDeviceAlertsSheet(context),
          child: Padding(
            padding: EdgeInsets.all(AppDimens.spacingMedium),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notification_important_rounded,
                    color: fg,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1
                            ? 'dash_alert_banner_one'.tr()
                            : 'dash_alert_banner_many'.tr(
                                args: {'count': '$count'},
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        latest.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'dash_alert_detail'.tr(
                          args: {
                            'type': latest.deviceType,
                            'rssi': '${latest.rssi}',
                          },
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: fg.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4.w),
                Tooltip(
                  message: 'dash_alert_review'.tr(),
                  child: Icon(Icons.chevron_right_rounded, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
