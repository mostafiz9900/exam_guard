import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class GuideStepTile extends StatelessWidget {
  const GuideStepTile({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12.r,
          backgroundColor: Theme.of(context).colorScheme.primary
              .withValues(alpha: 0.15),
          child: Text(
            stepNumber,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
