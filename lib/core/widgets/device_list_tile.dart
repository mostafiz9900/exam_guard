import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// A reusable list tile for scanned devices, with optional shimmer loading state.
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    this.isLoading = false,
    this.deviceName,
    this.deviceStatus,
    this.deviceId,
    this.signalStrength,
    this.onTap,
  });

  final bool isLoading;
  final String? deviceName;
  final String? deviceStatus;
  final String? deviceId;
  final int? signalStrength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShimmerTile();
    }

    final signalValue = signalStrength ?? -120;
    final signalColor = _getSignalColor(signalValue);
    final signalLabel = signalStrength != null ? '$signalStrength dBm' : '--';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMedium,
          vertical: AppDimens.spacingLarge,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Center(
                child: Text(
                  deviceName != null && deviceName!.isNotEmpty
                      ? deviceName!.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: AppDimens.heading3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(width: AppDimens.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName ?? 'UNKNOWN DEVICE',
                    style: TextStyle(
                      color: AppColors.textHighEmphasis,
                      fontSize: AppDimens.bodyLarge,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingExtraSmall),
                  Text(
                    deviceId ?? '---',
                    style: TextStyle(
                      color: AppColors.textLowEmphasis,
                      fontSize: AppDimens.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  signalLabel,
                  style: TextStyle(
                    color: signalColor,
                    fontSize: AppDimens.bodySmall,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppDimens.spacingExtraSmall),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingSmall,
                    vertical: AppDimens.spacingExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color: deviceStatus == 'active'
                        ? AppColors.success
                        : deviceStatus == 'warning'
                        ? AppColors.accent
                        : AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: Text(
                    deviceStatus?.toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: AppDimens.bodySmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -60) return AppColors.success;
    if (rssi >= -80) return AppColors.secondary;
    return AppColors.error;
  }

  Widget _buildShimmerTile() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMedium,
          vertical: AppDimens.spacingLarge,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
            ),
            SizedBox(width: AppDimens.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140.w,
                    height: 16.h,
                    color: AppColors.shimmerBase,
                  ),
                  SizedBox(height: AppDimens.spacingExtraSmall),
                  Container(
                    width: 100.w,
                    height: 12.h,
                    color: AppColors.shimmerBase,
                  ),
                ],
              ),
            ),
            Container(width: 60.w, height: 24.h, color: AppColors.shimmerBase),
          ],
        ),
      ),
    );
  }
}
