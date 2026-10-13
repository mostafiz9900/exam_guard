import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class GuideStepItem extends StatelessWidget {
  const GuideStepItem({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String stepNumber;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.15),
            child: Text(
              stepNumber,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16.w,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Radial Gauge Painter with Needle & Microtesla Ring
