import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/signal_bars_widget.dart';
import 'package:flutter/material.dart';

class ProfessionalDeviceCard extends StatelessWidget {
  const ProfessionalDeviceCard({
    super.key,
    required this.device,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
    required this.onDisconnectTap,
  });

  final ScannedDeviceModel device;
  final VoidCallback onTrackTap;
  final VoidCallback onLogTap;
  final VoidCallback onInfoTap;
  final VoidCallback onDisconnectTap;

  /// Strong signal = close = suspicious, so it is red (same thresholds as
  /// the dashboard: > -65 dBm strong, > -75 dBm near).
  Color _getSignalColor(int rssi) {
    if (rssi > -65) {
      return const Color(0xFFEF4444); // Red (very close)
    } else if (rssi > -75) {
      return const Color(0xFFF97316); // Orange (near)
    } else if (rssi > -88) {
      return const Color(0xFFF59E0B); // Amber (in range)
    } else {
      return const Color(0xFF10B981); // Green (distant)
    }
  }

  IconData _getDeviceCategoryIcon(String type) {
    if (type.contains('Hotspot') || type.contains('AP')) {
      return Icons.wifi_tethering_rounded;
    } else if (type.contains('Audio')) {
      return Icons.headset_mic_rounded;
    } else if (type.contains('Wearable')) {
      return Icons.watch_rounded;
    } else if (type.contains('Smartphone')) {
      return Icons.smartphone_rounded;
    } else if (type.contains('ESP32')) {
      return Icons.developer_board_rounded;
    } else {
      return Icons.bluetooth_searching_rounded;
    }
  }

  int _getSignalBars(int rssi) {
    if (rssi > -65) return 4;
    if (rssi > -75) return 3;
    if (rssi > -88) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor(device.rssi);
    final icon = _getDeviceCategoryIcon(device.deviceType);
    final bars = _getSignalBars(device.rssi);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: signalColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onInfoTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMedium),
          child: Column(
            children: [
              Row(
                children: [
                  // Category Icon Avatar
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: signalColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: signalColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: signalColor, size: 22.w),
                  ),
                  SizedBox(width: 10.w),

                  // Device Details & Manufacturer Tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        SizedBox(height: 3.h),
                        Wrap(
                          spacing: 4.w,
                          runSpacing: 4.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 130.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 1.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: signalColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5.r),
                                  border: Border.all(
                                    color: signalColor.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 10.w, color: signalColor),
                                    SizedBox(width: 3.w),
                                    Flexible(
                                      child: Text(
                                        deviceTypeShortLabel(device.deviceType),
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.bold,
                                          color: signalColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 110.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 1.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  manufacturerLabel(device.manufacturer),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MAC: ${device.id}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.access_time_rounded,
                              size: 10.w,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              AppDateFormat.clock(device.lastSeen),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Visual Signal Strength & 4-Bar Meter
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SignalBarsWidget(bars: bars, color: signalColor),
                          SizedBox(width: 4.w),
                          Text(
                            '${device.rssi} dBm',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: signalColor,
                                  fontSize: 12.sp,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: signalColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (device.isConnected) ...[
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green.shade300, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 14.w,
                            color: Colors.green.shade800,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'scan_connected_badge'.tr(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const Spacer(),
                          if (device.batteryLevel != null) ...[
                            Icon(
                              Icons.battery_std_rounded,
                              size: 12.w,
                              color: Colors.green.shade800,
                            ),
                            Text(
                              ' ${device.batteryLevel}%',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                          ),
                          onPressed: onDisconnectTap,
                          icon: Icon(Icons.link_off_rounded, size: 13.w),
                          label: Text(
                            'scan_disconnect'.tr(),
                            style: TextStyle(fontSize: 10.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 14),

              // Bottom Action Toolbar: Track Radar, Log Violation & Info
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTrackTap,
                      icon: Icon(
                        Icons.radar_rounded,
                        size: 15.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'scan_track_radar'.tr(),
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onLogTap,
                      icon: Icon(Icons.report_problem_rounded, size: 15.w),
                      label: Text(
                        'scan_log_violation'.tr(),
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, size: 18.w),
                    tooltip: 'scan_inspect_payload'.tr(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onInfoTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic 4-Bar Signal Indicator Widget
