import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class SignalBarsWidget extends StatelessWidget {
  const SignalBarsWidget({super.key, required this.bars, required this.color});

  final int bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final isActive = index < bars;
        final height = 5.h + (index * 2.5.h);
        return Container(
          width: 3.w,
          height: height,
          margin: EdgeInsets.only(right: 2.w),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2.r),
          ),
        );
      }),
    );
  }
}

/// Shimmer Skeleton Loading Card
