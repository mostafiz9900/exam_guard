import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final String count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22.w),
            SizedBox(height: 6.h),
            Text(
              count,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            SizedBox(height: 2.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
