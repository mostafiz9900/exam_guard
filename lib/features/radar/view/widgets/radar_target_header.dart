import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_sizes.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_colors.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_gauge.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Compact target identity: name, transport, trusted badge, id (long-press
/// copies it) and a live / searching / lost / off status pill.
class RadarTargetHeader extends StatelessWidget {
  const RadarTargetHeader({
    super.key,
    required this.device,
    required this.mode,
    required this.isTrusted,
    required this.onCopyId,
  });

  final ScannedDeviceModel device;
  final GaugeMode mode;
  final bool isTrusted;
  final VoidCallback onCopyId;

  static IconData transportIcon(DeviceTransport transport) =>
      switch (transport) {
        DeviceTransport.ble => Icons.bluetooth_searching_rounded,
        DeviceTransport.classic => Icons.bluetooth_rounded,
        DeviceTransport.wifi => Icons.wifi_rounded,
      };

  static String transportKey(DeviceTransport transport) => switch (transport) {
    DeviceTransport.ble => 'scan_transport_ble',
    DeviceTransport.classic => 'scan_transport_classic',
    DeviceTransport.wifi => 'scan_transport_wifi',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (String statusKey, Color statusColor) = switch (mode) {
      GaugeMode.live => ('radar_status_live', AppColors.success),
      GaugeMode.acquiring => ('radar_status_searching', closenessStops[2]),
      GaugeMode.lost => ('radar_status_lost', colors.error),
      GaugeMode.off => ('radar_status_off', colors.outline),
    };

    return Card(
      key: const Key('radar_target_header'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Semantics(
        onLongPressHint: 'radar_copy_id_hint'.tr(),
        child: InkWell(
          onLongPress: onCopyId,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimens.spacingSmall,
              vertical: 10.rc,
            ),
            child: Row(
              children: [
                _Avatar(
                  icon: transportIcon(device.transport),
                  dotColor: statusColor,
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.displayName,
                              key: const Key('radar_target_name'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (isTrusted) ...[
                            SizedBox(width: 4.rc),
                            Tooltip(
                              message: 'scan_trusted_badge'.tr(),
                              child: Semantics(
                                label: 'scan_trusted_badge'.tr(),
                                child: Icon(
                                  Icons.verified_rounded,
                                  key: const Key('radar_trusted_badge'),
                                  size: 18.rc,
                                  color: readableInk(
                                    context,
                                    AppColors.success,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.rc),
                      Row(
                        children: [
                          Flexible(
                            child: _Tag(
                              label: transportKey(device.transport).tr(),
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(width: 8.rc),
                          Expanded(
                            flex: 3,
                            child: Text(
                              device.address,
                              key: const Key('radar_target_id'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 0.3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.rc),
                _StatusPill(label: statusKey.tr(), color: statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.dotColor});

  final IconData icon;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = 44.rc;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.primary, size: 24.rc),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 13.rc,
              height: 13.rc,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = readableInk(context, color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.rc, vertical: 1.rc),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6.rc),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = readableInk(context, color);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        key: const Key('radar_status_pill'),
        padding: EdgeInsets.symmetric(horizontal: 10.rc, vertical: 5.rc),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20.rc),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.rc,
              height: 8.rc,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: 6.rc),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
