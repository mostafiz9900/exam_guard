import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Devices that appeared after the empty-room baseline and haven't been
/// acknowledged yet, with "Mark all seen".
class NewDeviceAlertsBanner extends StatelessWidget {
  const NewDeviceAlertsBanner({
    super.key,
    required this.alerts,
    required this.onMarkAllSeen,
  });

  /// Unacknowledged alerts, newest first.
  final List<NewDeviceAlert> alerts;
  final VoidCallback onMarkAllSeen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final names = alerts
        .take(3)
        .map((a) => '${a.displayName} (${transportLabel(a.transport)})')
        .join(', ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(12.w, 8.h, 4.w, 8.h),
        child: Row(
          children: [
            Icon(
              Icons.notification_important_rounded,
              color: scheme.onErrorContainer,
              size: 22.w,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'scan_alerts_title'.tr(args: {'count': '${alerts.length}'}),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                minimumSize: const Size(0, 40),
              ),
              onPressed: onMarkAllSeen,
              child: Text('scan_alerts_mark_seen'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
