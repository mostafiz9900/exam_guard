import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Reusable shimmer loader that can be used for placeholder content across ExamGuard.
class CustomShimmerLoader extends StatelessWidget {
  const CustomShimmerLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16.0,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 128.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
