import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class RadarRing extends StatelessWidget {
  const RadarRing({super.key, required this.scale, required this.opacity});
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 110.w,
        height: 110.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: opacity.clamp(0.0, 1.0)),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
