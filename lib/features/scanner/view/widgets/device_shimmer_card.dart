import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

class DeviceShimmerCard extends StatelessWidget {
  const DeviceShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 80.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 130.w, height: 12.h, color: Colors.white),
                  SizedBox(height: 6.h),
                  Container(width: 80.w, height: 9.h, color: Colors.white),
                ],
              ),
            ),
            Container(
              width: 50.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactical Sweep Rotating Radar Painter
