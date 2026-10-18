import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';

/// Grey "not measuring" banner with the reason and the fix (never shows an
/// all-clear while the scan cannot hear anything).
class FinderIssueBanner extends StatelessWidget {
  const FinderIssueBanner({
    super.key,
    required this.issue,
    required this.onOpenLocation,
    required this.onTurnOnBluetooth,
    required this.onRetry,
  });

  final FinderScanIssue issue;
  final VoidCallback onOpenLocation;
  final VoidCallback onTurnOnBluetooth;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (
      IconData icon,
      String actionKey,
      VoidCallback action,
    ) = switch (issue) {
      FinderScanIssue.locationOff => (
        Icons.location_off_rounded,
        'radar_turn_on_location',
        onOpenLocation,
      ),
      FinderScanIssue.bluetoothOff => (
        Icons.bluetooth_disabled_rounded,
        'walk_turn_on_bluetooth',
        onTurnOnBluetooth,
      ),
      FinderScanIssue.throttled || FinderScanIssue.failed => (
        Icons.error_outline_rounded,
        'radar_retry',
        onRetry,
      ),
    };

    return Container(
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.outline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.outline, size: 26.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.titleKey.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      issue.textKey.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: action,
              child: Text(actionKey.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
