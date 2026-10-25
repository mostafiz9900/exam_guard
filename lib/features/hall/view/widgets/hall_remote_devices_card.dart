import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/dashboard/view/widgets/signal_strength.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/distance_text.dart';

/// Devices other members hear right now, with who heard them and how far
/// they are from that member.
class HallRemoteDevicesCard extends StatelessWidget {
  const HallRemoteDevicesCard({super.key, required this.devices});

  final List<RemoteDevice> devices;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
              child: Text(
                'hall_devices_title'.tr(args: {'count': '${devices.length}'}),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (devices.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppDimens.spacingMedium),
                child: Text(
                  'hall_devices_empty'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final r in devices)
              ListTile(
                dense: true,
                leading: Icon(
                  transportIcon(r.device.transport),
                  color: SignalStrength.color(r.device.rssi, colors),
                ),
                title: Text(
                  r.device.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${deviceTypeShortLabel(r.device.deviceType)} · '
                  '${'hall_heard_by'.tr(args: {'name': r.sourceName})}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  signalSummaryText(
                    r.device.rssi,
                    r.device.transport,
                    txPower: r.device.txPower,
                  ),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: SignalStrength.color(r.device.rssi, colors),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
