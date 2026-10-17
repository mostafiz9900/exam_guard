import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view/widgets/radar_ring.dart';
import 'package:exam_guard/features/scanner/view/widgets/tactical_sweep_painter.dart';

/// What the scanner is doing right now, as shown in the status card.
enum ScannerStatusKind { live, locationOff, bluetoothOff, failed, paused }

/// Compact scanner status: a small animated radar plus a status badge and
/// a one-line explanation. Scrolls away with the page.
class ScannerStatusCard extends StatelessWidget {
  const ScannerStatusCard({
    super.key,
    required this.kind,
    required this.deviceCount,
    required this.signalCount,
    required this.pulse,
    required this.sweep,
  });

  final ScannerStatusKind kind;

  /// Likely physical devices (grouped addresses count once).
  final int deviceCount;

  /// Individual BLE addresses heard.
  final int signalCount;
  final Animation<double> pulse;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLive = kind == ScannerStatusKind.live;

    final (
      Color tone,
      IconData icon,
      String badge,
      String detail,
    ) = switch (kind) {
      ScannerStatusKind.live => (
        scheme.primary,
        Icons.bluetooth_searching_rounded,
        'scan_live_devices'.tr(args: {'count': '$deviceCount'}),
        'scan_signal_summary'.tr(
          args: {'devices': '$deviceCount', 'signals': '$signalCount'},
        ),
      ),
      ScannerStatusKind.locationOff => (
        scheme.error,
        Icons.location_off_rounded,
        'scan_badge_location_off'.tr(),
        'scan_location_resume_hint'.tr(),
      ),
      ScannerStatusKind.bluetoothOff => (
        scheme.error,
        Icons.bluetooth_disabled_rounded,
        'status_bluetooth_off'.tr(),
        'feed_bluetooth_off'.tr(),
      ),
      ScannerStatusKind.failed => (
        scheme.error,
        Icons.error_outline_rounded,
        'status_scan_failed'.tr(),
        'scan_failed_hint'.tr(),
      ),
      ScannerStatusKind.paused => (
        scheme.onSurfaceVariant,
        Icons.pause_circle_outline_rounded,
        'scan_paused'.tr(),
        'scan_empty_refresh_hint'.tr(),
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
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            _MiniRadar(
              isLive: isLive,
              tone: tone,
              icon: icon,
              pulse: pulse,
              sweep: sweep,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: tone,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniRadar extends StatelessWidget {
  const _MiniRadar({
    required this.isLive,
    required this.tone,
    required this.icon,
    required this.pulse,
    required this.sweep,
  });

  final bool isLive;
  final Color tone;
  final IconData icon;
  final Animation<double> pulse;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final size = 52.w;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLive) ...[
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => RadarRing(
                size: size,
                color: tone,
                scale: 0.4 + pulse.value * 0.6,
                opacity: (1.0 - pulse.value).clamp(0.0, 1.0),
              ),
            ),
            AnimatedBuilder(
              animation: sweep,
              builder: (context, _) => CustomPaint(
                size: Size.square(size),
                painter: TacticalSweepPainter(
                  angle: sweep.value * 2 * math.pi,
                  color: tone,
                ),
              ),
            ),
          ] else
            RadarRing(size: size, color: tone, scale: 0.9, opacity: 0.3),
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 18.w, color: tone),
          ),
        ],
      ),
    );
  }
}
