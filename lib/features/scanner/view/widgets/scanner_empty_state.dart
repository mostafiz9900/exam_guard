import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Says why the device list is empty and offers the one action that helps.
/// [ScannerEmptyReason.waiting] is shown as shimmer cards by the screen.
class ScannerEmptyState extends StatelessWidget {
  const ScannerEmptyState({
    super.key,
    required this.reason,
    required this.totalDevices,
    required this.roomLabel,
    this.errorText,
    required this.onEnableBluetooth,
    required this.onRetry,
    required this.onShowAll,
    required this.onDisableBoundary,
    this.onOpenSettings,
  });

  final ScannerEmptyReason reason;

  /// Devices found in total (for filteredOut: inside the boundary).
  final int totalDevices;

  /// Translated room size of the boundary, e.g. "Standard hall (~4.5 m)".
  final String roomLabel;

  /// Translated blocking error, for [ScannerEmptyReason.error].
  final String? errorText;
  final VoidCallback onEnableBluetooth;
  final VoidCallback onRetry;
  final VoidCallback onShowAll;
  final VoidCallback onDisableBoundary;

  /// Set when the error can only be fixed in the OS settings (permission
  /// permanently denied); replaces "Try again" for [ScannerEmptyReason.error].
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = '$totalDevices';

    final (
      IconData icon,
      Color tone,
      String title,
      String? hint,
      String? action,
      IconData? actionIcon,
      VoidCallback? onAction,
    ) = switch (reason) {
      ScannerEmptyReason.locationOff => (
        Icons.location_off_rounded,
        scheme.error,
        'scan_empty_location_off'.tr(),
        null,
        null,
        null,
        null,
      ),
      ScannerEmptyReason.bluetoothOff => (
        Icons.bluetooth_disabled_rounded,
        scheme.error,
        'scan_bt_off_title'.tr(),
        'scan_bt_off_message'.tr(),
        'scan_bt_turn_on'.tr(),
        Icons.bluetooth_searching_rounded,
        onEnableBluetooth,
      ),
      ScannerEmptyReason.error => (
        Icons.error_outline_rounded,
        scheme.error,
        errorText ?? 'status_scan_failed'.tr(),
        null,
        onOpenSettings != null
            ? 'scan_open_settings'.tr()
            : 'scan_try_again'.tr(),
        onOpenSettings != null ? Icons.settings_rounded : Icons.refresh_rounded,
        onOpenSettings ?? onRetry,
      ),
      ScannerEmptyReason.waiting => (
        Icons.bluetooth_searching_rounded,
        scheme.primary,
        'scan_empty_scanning'.tr(),
        null,
        null,
        null,
        null,
      ),
      ScannerEmptyReason.paused => (
        Icons.pause_circle_outline_rounded,
        scheme.onSurfaceVariant,
        'feed_scan_stopped'.tr(),
        null,
        'start_scanning'.tr(),
        Icons.play_arrow_rounded,
        onRetry,
      ),
      ScannerEmptyReason.outsideBoundary => (
        Icons.meeting_room_rounded,
        scheme.primary,
        'scan_empty_outside_boundary'.tr(
          args: {'count': count, 'room': roomLabel},
        ),
        'scan_empty_boundary_hint'.tr(),
        'scan_boundary_turn_off'.tr(),
        Icons.public_rounded,
        onDisableBoundary,
      ),
      ScannerEmptyReason.filteredOut => (
        Icons.filter_alt_off_rounded,
        scheme.primary,
        'scan_empty_filter'.tr(args: {'count': count}),
        null,
        'scan_show_all'.tr(),
        Icons.select_all_rounded,
        onShowAll,
      ),
    };

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36.w, color: tone),
            SizedBox(height: 10.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (hint != null) ...[
              SizedBox(height: 4.h),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null && onAction != null) ...[
              SizedBox(height: 14.h),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
