import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Small info row: phone hotspot detection is off, and why. Not shown for
/// [WifiScanProblem.unsupported] (iOS can't scan Wi-Fi; nothing to fix).
class WifiProblemBanner extends StatelessWidget {
  const WifiProblemBanner({super.key, required this.problem});

  final WifiScanProblem problem;

  /// True when [problem] is worth telling the invigilator about.
  static bool shows(WifiScanProblem? problem) =>
      problem != null && problem != WifiScanProblem.unsupported;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reason = switch (problem) {
      WifiScanProblem.permissionDenied => 'scan_wifi_problem_permission',
      WifiScanProblem.locationOff => 'scan_wifi_problem_location',
      WifiScanProblem.wifiOff => 'scan_wifi_problem_wifi_off',
      WifiScanProblem.unsupported => 'scan_wifi_problem_unsupported',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18.w,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'scan_wifi_off_title'.tr(),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  reason.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
