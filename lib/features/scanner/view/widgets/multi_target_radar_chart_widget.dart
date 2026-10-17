import 'dart:math' as math;

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/widgets/multi_target_radar_painter.dart';
import 'package:flutter/material.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = math.min(constraints.maxWidth, 280.w);

        return Column(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final localPos = details.localPosition;
                final center = Offset(chartSize / 2, chartSize / 2);
                final maxRadius = chartSize / 2;

                for (int i = 0; i < devices.length; i++) {
                  final device = devices[i];
                  final blipRatio = ((device.rssi + 100).clamp(0, 70) / 70.0)
                      .clamp(0.1, 0.9);
                  final blipDistance = maxRadius * (1.0 - blipRatio);
                  final blipAngle =
                      -math.pi / 2 +
                      (i * 2 * math.pi / math.max(1, devices.length));

                  final blipX = center.dx + blipDistance * math.cos(blipAngle);
                  final blipY = center.dy + blipDistance * math.sin(blipAngle);
                  final blipPos = Offset(blipX, blipY);

                  if ((localPos - blipPos).distance <= 24.w) {
                    onDeviceTap(device);
                    return;
                  }
                }
              },
              child: AnimatedBuilder(
                animation: sweepController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(chartSize, chartSize),
                    painter: MultiTargetRadarPainter(
                      sweepAngle: sweepController.value * 2 * math.pi,
                      devices: devices,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            // Quick Target Selection Chips Row for 1-Tap Tracking
            Text(
              'scan_radar_tap_hint'.tr(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontSize: 10.sp, color: Colors.grey),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: devices.map((d) {
                final color = d.rssi > -60
                    ? const Color(0xFFEF4444)
                    : (d.rssi > -75
                          ? const Color(0xFFF97316)
                          : const Color(0xFF10B981));
                return ActionChip(
                  avatar: CircleAvatar(backgroundColor: color, radius: 4.r),
                  label: Text(
                    '${d.displayName} (${d.rssi}dBm)',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => onDeviceTap(d),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// Custom Painter for 360° Multi-Target Radar Chart plotting ALL discovered devices
