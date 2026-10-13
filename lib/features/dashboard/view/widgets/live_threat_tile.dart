import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter/material.dart';

class LiveThreatTile extends StatelessWidget {
  const LiveThreatTile({
    super.key,
    required this.device,
    required this.onTrackTap,
  });

  final ScannedDeviceModel device;
  final VoidCallback onTrackTap;

  Color _getSignalColor(int rssi) {
    if (rssi > -60) return const Color(0xFF10B981);
    if (rssi > -75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getSignalColor(device.rssi);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 18.r,
          child: Icon(
            Icons.bluetooth_searching_rounded,
            color: color,
            size: 18.w,
          ),
        ),
        title: Text(
          device.displayName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${device.manufacturer} • MAC: ${device.id}',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey.shade600,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ElevatedButton.icon(
          onPressed: onTrackTap,
          icon: Icon(Icons.radar_rounded, size: 14.w),
          label: Text('Track', style: TextStyle(fontSize: 10.sp)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
