import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/detail_row.dart';

/// Shows the BLE payload and vendor details of [device].
Future<void> showDeviceDetailsSheet(
  BuildContext context,
  ScannedDeviceModel device, {
  required VoidCallback onConnect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _DeviceDetailsSheet(device: device, onConnect: onConnect),
  );
}

class _DeviceDetailsSheet extends StatelessWidget {
  const _DeviceDetailsSheet({required this.device, required this.onConnect});

  final ScannedDeviceModel device;
  final VoidCallback onConnect;

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
              label: 'scan_detail_mac'.tr(),
              value: device.id,
              monospace: true,
            ),
            DetailRow(
              label: 'scan_detail_rssi'.tr(),
              value: '${device.rssi} dBm',
            ),
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
            if (device.serviceUuids.isNotEmpty)
              DetailRow(
                label: 'scan_detail_services'.tr(),
                value: device.serviceUuids.join(', '),
              ),
            if (device.isConnectable &&
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
