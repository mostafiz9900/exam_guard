import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/distance_text.dart';

/// "{name} detected: …" line shared by the hall screen and the dashboard.
String remoteAlertText(RemoteAlert a) => 'hall_alert_from'.tr(
  args: {
    'name': a.sourceName,
    'type': deviceTypeShortLabel(a.alert.deviceType),
    'signal': signalSummaryText(a.alert.rssi, a.alert.transport),
  },
);

/// New-device alerts raised by other members, newest first.
class HallAlertsCard extends StatelessWidget {
  const HallAlertsCard({
    super.key,
    required this.alerts,
    required this.onAcknowledgeAll,
  });

  final List<RemoteAlert> alerts;
  final VoidCallback onAcknowledgeAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pending = alerts.where((a) => !a.alert.acknowledged).length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'hall_alerts_title'.tr(),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (pending > 0)
                    TextButton(
                      onPressed: onAcknowledgeAll,
                      child: Text('hall_ack_all'.tr()),
                    ),
                ],
              ),
            ),
            for (final a in alerts)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: a.alert.acknowledged
                      ? colors.onSurfaceVariant
                      : colors.error,
                ),
                // What and how far first; who found it and when below.
                title: Text(
                  '${deviceTypeShortLabel(a.alert.deviceType)} · '
                  '${signalSummaryText(a.alert.rssi, a.alert.transport)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${a.alert.displayName} · '
                  '${'hall_heard_by'.tr(args: {'name': a.sourceName})} · '
                  '${AppDateFormat.clock(a.alert.detectedAt)}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
