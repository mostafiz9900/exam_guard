import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

/// Placeholder card shown while waiting for the first advertisement.
class DeviceShimmerCard extends StatelessWidget {
  const DeviceShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The shimmer paints its own gradient over these shapes; any opaque
    // color works as the mask.
    const mask = Colors.white;
    return AppShimmer(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerLow,
      child: Container(
        height: 72.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: mask,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: mask,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 130.w, height: 12.h, color: mask),
                  SizedBox(height: 6.h),
                  Container(width: 80.w, height: 9.h, color: mask),
                ],
              ),
            ),
            Container(
              width: 50.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: mask,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
