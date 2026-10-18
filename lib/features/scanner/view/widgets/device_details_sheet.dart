import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/detail_row.dart';

/// Shows the payload and vendor details of [device], with Trust/Untrust.
Future<void> showDeviceDetailsSheet(
  BuildContext context,
  ScannedDeviceModel device, {
  required VoidCallback onConnect,
  required bool isTrusted,
  required VoidCallback onToggleTrust,
  VoidCallback? onSeatSweep,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _DeviceDetailsSheet(
      device: device,
      onConnect: onConnect,
      isTrusted: isTrusted,
      onToggleTrust: onToggleTrust,
      onSeatSweep: onSeatSweep,
    ),
  );
}

class _DeviceDetailsSheet extends StatelessWidget {
  const _DeviceDetailsSheet({
    required this.device,
    required this.onConnect,
    required this.isTrusted,
    required this.onToggleTrust,
    this.onSeatSweep,
  });

  final ScannedDeviceModel device;
  final VoidCallback onConnect;
  final bool isTrusted;
  final VoidCallback onToggleTrust;

  /// Shown only when a seat sweep is possible (BLE, exam with seat map).
  final VoidCallback? onSeatSweep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spacingMedium,
          0,
          AppDimens.spacingMedium,
          AppDimens.spacingMedium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 22.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        deviceTypeLabel(device.deviceType),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            DetailRow(
              label: 'scan_detail_manufacturer'.tr(),
              value: manufacturerLabel(device.manufacturer),
            ),
            DetailRow(
              label: 'scan_detail_transport'.tr(),
              value: transportLabel(device.transport),
            ),
            DetailRow(
              label: device.transport == DeviceTransport.wifi
                  ? 'scan_detail_bssid'.tr()
                  : 'scan_detail_mac'.tr(),
              value: device.address,
              monospace: true,
            ),
            DetailRow(
              label: 'scan_detail_rssi'.tr(),
              value: '${device.rssi} dBm',
            ),
            if (device.isBle) ...[
              DetailRow(
                label: 'scan_detail_tx_power'.tr(),
                value: device.txPower != null
                    ? '${device.txPower} dBm'
                    : 'scan_detail_not_advertised'.tr(),
              ),
              DetailRow(
                label: 'scan_detail_connection'.tr(),
                value: device.isConnectable
                    ? 'scan_detail_connectable'.tr()
                    : 'scan_detail_broadcast_only'.tr(),
              ),
            ],
            if (device.serviceUuids.isNotEmpty)
              DetailRow(
                label: 'scan_detail_services'.tr(),
                value: device.serviceUuids.join(', '),
              ),
            SizedBox(height: AppDimens.spacingSmall),
            Text(
              'scan_trust_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            SizedBox(
              width: double.infinity,
              child: (isTrusted ? OutlinedButton.icon : FilledButton.tonalIcon)(
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onToggleTrust();
                },
                icon: Icon(
                  isTrusted
                      ? Icons.remove_moderator_rounded
                      : Icons.verified_user_rounded,
                ),
                label: Text(
                  isTrusted ? 'scan_untrust'.tr() : 'scan_trust'.tr(),
                ),
              ),
            ),
            if (onSeatSweep case final sweep?) ...[
              SizedBox(height: AppDimens.spacingSmall),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    sweep();
                  },
                  icon: const Icon(Icons.event_seat_rounded),
                  label: Text('scan_seat_sweep'.tr()),
                ),
              ),
            ],
            if (device.isBle &&
                device.isConnectable &&
                !device.isConnected &&
                !device.isConnecting) ...[
              SizedBox(height: AppDimens.spacingSmall),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onConnect();
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: Text('scan_connect_read_info'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
