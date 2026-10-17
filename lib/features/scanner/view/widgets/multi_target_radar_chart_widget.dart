import 'dart:math' as math;

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/widgets/multi_target_radar_painter.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:flutter/material.dart';

/// All shown devices on one chart. Rings are estimated distance from the
/// signal strength; the position around the circle is NOT a direction.
class MultiTargetRadarChartWidget extends StatelessWidget {
  const MultiTargetRadarChartWidget({
    super.key,
    required this.devices,
    required this.sweepController,
    required this.onDeviceTap,
  });

  final List<ScannedDeviceModel> devices;
  final AnimationController sweepController;
  final void Function(ScannedDeviceModel device) onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = math.min(constraints.maxWidth, 280.w);
        final size = Size.square(chartSize);

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16.w,
                    color: scheme.onTertiaryContainer,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'scan_radar_caption'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            GestureDetector(
              onTapUp: (details) {
                // Nearest dot within reach, so overlapping dots stay usable.
                ScannedDeviceModel? hit;
                var best = 24.w;
                for (final device in devices) {
                  final d =
                      (details.localPosition - radarPositionFor(device, size))
                          .distance;
                  if (d <= best) {
                    best = d;
                    hit = device;
                  }
                }
                if (hit != null) onDeviceTap(hit);
              },
              child: AnimatedBuilder(
                animation: sweepController,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: MultiTargetRadarPainter(
                      sweepAngle: sweepController.value * 2 * math.pi,
                      devices: devices,
                      gridColor: scheme.outline,
                      labelColor: scheme.onSurfaceVariant,
                      labelBackground: scheme.surface,
                      accent: scheme.primary,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'scan_radar_tap_hint'.tr(),
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: [
                for (final d in devices)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: signalColorFor(d.rssi),
                      radius: 4.r,
                    ),
                    label: Text('${d.displayName} (${d.rssi} dBm)'),
                    labelStyle: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    onPressed: () => onDeviceTap(d),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
