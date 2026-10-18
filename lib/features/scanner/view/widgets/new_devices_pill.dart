import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Floating "N new devices ↓" pill: new devices were added below the part
/// of the list the invigilator is looking at.
class NewDevicesPill extends StatelessWidget {
  const NewDevicesPill({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      elevation: 4,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'scan_new_below'.tr(args: {'count': '$count'}),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: scheme.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
