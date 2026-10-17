import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/signal_bars_widget.dart';

/// Minimum touch target for buttons on the card.
const double _tapTarget = 40;

/// Strong signal = close = suspicious, so it is red (same thresholds as
/// the dashboard: > -65 dBm strong, > -75 dBm near).
Color signalColorFor(int rssi) {
  if (rssi > -65) return const Color(0xFFEF4444);
  if (rssi > -75) return const Color(0xFFF97316);
  if (rssi > -88) return const Color(0xFFF59E0B);
  return const Color(0xFF10B981);
}

int _signalBars(int rssi) {
  if (rssi > -65) return 4;
  if (rssi > -75) return 3;
  if (rssi > -88) return 2;
  return 1;
}

IconData _categoryIcon(String type) {
  if (type.contains('Hotspot') || type.contains('AP')) {
    return Icons.wifi_tethering_rounded;
  }
  if (type.contains('Audio')) return Icons.headset_mic_rounded;
  if (type.contains('Wearable')) return Icons.watch_rounded;
  if (type.contains('Smartphone')) return Icons.smartphone_rounded;
  if (type.contains('ESP32')) return Icons.developer_board_rounded;
  return Icons.bluetooth_searching_rounded;
}

/// One likely physical device. When several addresses were grouped, a
/// "+N IDs" row expands to list each address, each still trackable and
/// loggable on its own.
class ProfessionalDeviceCard extends HookWidget {
  const ProfessionalDeviceCard({
    super.key,
    required this.group,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
    required this.onDisconnectTap,
  });

  final ScannedDeviceGroup group;
  final ValueChanged<ScannedDeviceModel> onTrackTap;
  final ValueChanged<ScannedDeviceModel> onLogTap;
  final ValueChanged<ScannedDeviceModel> onInfoTap;
  final ValueChanged<ScannedDeviceModel> onDisconnectTap;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final device = group.primary;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final signalColor = signalColorFor(device.rssi);
    final bars = _signalBars(device.rssi);
    final icon = _categoryIcon(device.deviceType);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: signalColor.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () => onInfoTap(device),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: signalColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, color: signalColor, size: 18.w),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3.h),
                        Wrap(
                          spacing: 4.w,
                          runSpacing: 3.h,
                          children: [
                            _Tag(
                              icon: icon,
                              text: deviceTypeShortLabel(device.deviceType),
                              color: signalColor,
                            ),
                            _Tag(
                              text: manufacturerLabel(device.manufacturer),
                              color: scheme.primary,
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.id,
                                style: textTheme.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.access_time_rounded,
                              size: 11.w,
                              color: scheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              AppDateFormat.clock(device.lastSeen),
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SignalBarsWidget(bars: bars, color: signalColor),
                          SizedBox(width: 2.w),
                          Text(
                            '${device.rssi} dBm',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: signalColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        switch (bars) {
                          4 => 'scan_proximity_very_close'.tr(),
                          3 => 'scan_proximity_near'.tr(),
                          2 => 'scan_proximity_in_range'.tr(),
                          _ => 'scan_proximity_distant'.tr(),
                        },
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: signalColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (device.isConnected)
                _ConnectedStrip(
                  batteryLevel: device.batteryLevel,
                  onDisconnect: () => onDisconnectTap(device),
                ),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onTrackTap(device),
                      icon: const Icon(Icons.radar_rounded, size: 16),
                      label: Text(
                        'track'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, _tapTarget),
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onLogTap(device),
                      icon: const Icon(Icons.report_problem_rounded, size: 16),
                      label: Text(
                        'scan_log_violation'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, _tapTarget),
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    tooltip: 'scan_inspect_payload'.tr(),
                    constraints: const BoxConstraints.tightFor(
                      width: _tapTarget,
                      height: _tapTarget,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => onInfoTap(device),
                  ),
                ],
              ),
              if (group.isGrouped)
                _GroupToggle(
                  extraIds: group.others.length,
                  expanded: expanded.value,
                  onTap: () => expanded.value = !expanded.value,
                ),
              if (group.isGrouped && expanded.value)
                _GroupMembers(
                  members: group.others,
                  onTrackTap: onTrackTap,
                  onLogTap: onLogTap,
                  onInfoTap: onInfoTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 140.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11.w, color: color),
              SizedBox(width: 3.w),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedStrip extends StatelessWidget {
  const _ConnectedStrip({
    required this.batteryLevel,
    required this.onDisconnect,
  });

  final int? batteryLevel;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success);
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsetsDirectional.only(start: 8.w),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 14.w, color: AppColors.success),
          SizedBox(width: 4.w),
          Text('scan_connected_badge'.tr(), style: style),
          if (batteryLevel != null) ...[
            SizedBox(width: 10.w),
            Icon(
              Icons.battery_std_rounded,
              size: 13.w,
              color: AppColors.success,
            ),
            Text('$batteryLevel%', style: style),
          ],
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              minimumSize: const Size(0, _tapTarget),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off_rounded, size: 16),
            label: Text('scan_disconnect'.tr()),
          ),
        ],
      ),
    );
  }
}

class _GroupToggle extends StatelessWidget {
  const _GroupToggle({
    required this.extraIds,
    required this.expanded,
    required this.onTap,
  });

  final int extraIds;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _tapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_rounded,
                    size: 16.w,
                    color: scheme.onSecondaryContainer,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'scan_group_chip'.tr(args: {'count': '$extraIds'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMembers extends StatelessWidget {
  const _GroupMembers({
    required this.members,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
  });

  final List<ScannedDeviceModel> members;
  final ValueChanged<ScannedDeviceModel> onTrackTap;
  final ValueChanged<ScannedDeviceModel> onLogTap;
  final ValueChanged<ScannedDeviceModel> onInfoTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Text(
              'scan_group_explain'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final m in members)
            InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: () => onInfoTap(m),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 4.w),
                child: Row(
                  children: [
                    if (m.isConnected) ...[
                      Icon(
                        Icons.link_rounded,
                        size: 14.w,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Expanded(
                      child: Text(
                        m.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      '${m.rssi} dBm',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: signalColorFor(m.rssi),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.radar_rounded, size: 20),
                      tooltip: 'scan_track_radar'.tr(),
                      color: scheme.primary,
                      constraints: const BoxConstraints.tightFor(
                        width: _tapTarget,
                        height: _tapTarget,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => onTrackTap(m),
                    ),
                    IconButton(
                      icon: const Icon(Icons.report_problem_rounded, size: 20),
                      tooltip: 'scan_log_violation'.tr(),
                      color: scheme.error,
                      constraints: const BoxConstraints.tightFor(
                        width: _tapTarget,
                        height: _tapTarget,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => onLogTap(m),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
