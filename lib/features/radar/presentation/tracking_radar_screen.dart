import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/audio/geiger_buzzer_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/primary_button.dart';
import '../../scanner/application/scanner_provider.dart';
import '../../scanner/domain/scanned_device_model.dart';
import '../application/tracking_radar_provider.dart';

class TrackingRadarScreen extends HookConsumerWidget {
  const TrackingRadarScreen({super.key, this.targetDevice});

  final ScannedDeviceModel? targetDevice;

  Color _getThreatColor(ThreatLevel threat) {
    switch (threat) {
      case ThreatLevel.critical:
        return const Color(0xFFEF4444); // Red
      case ThreatLevel.high:
        return const Color(0xFFF97316); // Orange
      case ThreatLevel.medium:
        return const Color(0xFFF59E0B); // Yellow
      case ThreatLevel.low:
        return const Color(0xFF10B981); // Green
    }
  }

  Color _getTrendColor(ProximityTrend trend) {
    switch (trend) {
      case ProximityTrend.approaching:
        return const Color(0xFF10B981); // Green (Getting Closer)
      case ProximityTrend.receding:
        return const Color(0xFFEF4444); // Red (Moving Away)
      case ProximityTrend.stationary:
        return const Color(0xFF3B82F6); // Blue (Position Locked)
    }
  }

  IconData _getTrendIcon(ProximityTrend trend) {
    switch (trend) {
      case ProximityTrend.approaching:
        return Icons.navigation_rounded;
      case ProximityTrend.receding:
        return Icons.subdirectory_arrow_left_rounded;
      case ProximityTrend.stationary:
        return Icons.my_location_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarState = ref.watch(trackingRadarProvider);
    final radarNotifier = ref.read(trackingRadarProvider.notifier);

    // Initialize target device when screen mounts or targetDevice changes
    useEffect(() {
      if (targetDevice != null) {
        Future.microtask(() => radarNotifier.setTargetDevice(targetDevice!));
      }
      return null;
    }, [targetDevice]);

    // Stream live RSSI updates from scannerProvider if targetDevice matches
    ref.listen(scannerProvider, (previous, next) {
      final currentTarget = radarState.device ?? targetDevice;
      if (currentTarget != null) {
        final updated = next.devices.firstWhere(
          (d) => d.id == currentTarget.id,
          orElse: () => currentTarget,
        );
        if (updated.rssi != currentTarget.rssi) {
          radarNotifier.updateDeviceSignal(updated.rssi, updated.lastSeen);
        }
      }
    });

    // Drive Geiger Audio Beep loop based on distance
    useEffect(() {
      if (radarState.isAudioAlertEnabled && radarState.distanceMeters > 0) {
        GeigerBuzzerService.instance
            .updateTargetDistance(radarState.distanceMeters);
      } else {
        GeigerBuzzerService.instance.stopBuzzer();
      }
      return () => GeigerBuzzerService.instance.stopBuzzer();
    }, [radarState.distanceMeters, radarState.isAudioAlertEnabled]);

    // Radar beam rotation animation controller
    final beamController = useAnimationController(
      duration: const Duration(seconds: 3),
    )..repeat();

    final activeDevice = radarState.device ?? targetDevice;
    final threatColor = _getThreatColor(radarState.threatLevel);
    final trendColor = _getTrendColor(radarState.trend);
    final trendIcon = _getTrendIcon(radarState.trend);

    return Scaffold(
      appBar: AppBar(
        title: Text('tracking_radar'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 24.w,
            ),
            tooltip: 'Direction Finding Guide',
            onPressed: () => _showDirectionGuideModal(context),
          ),
          IconButton(
            icon: Icon(
              radarState.isAudioAlertEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            tooltip: 'Toggle Audio Alert',
            onPressed: () => radarNotifier.toggleAudioAlert(),
          ),
          const AppSettingsMenu(),
        ],
      ),
      body: SafeArea(
        child: activeDevice == null
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(AppDimens.spacingLarge),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.radar_outlined,
                        size: 64.w,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No Target Device Selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Select a device from the Wireless Scanner to begin live radar tracking.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      SizedBox(height: 24.h),
                      PrimaryButton(
                        label: 'Open Wireless Scanner',
                        onPressed: () => context.go('/scanner'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(AppDimens.spacingLarge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live Dynamic Direction Guidance Banner
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingMedium,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: trendColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
                            border: Border.all(
                              color: trendColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                trendIcon,
                                color: trendColor,
                                size: 24.w,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      radarState.trend.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: trendColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.sp,
                                          ),
                                    ),
                                    Text(
                                      radarState.trend.instruction,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 10.sp,
                                            color: Colors.grey.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingMedium),

                        // Threat Status Banner
                        Container(
                          padding: EdgeInsets.all(AppDimens.spacingMedium),
                          decoration: BoxDecoration(
                            color: threatColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
                            border: Border.all(
                              color: threatColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: threatColor,
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 20.w,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      radarState.threatLevel.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: threatColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      radarState.threatLevel.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Radar Visual Display Map with Distance Meters Labels & Direction Vector
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusLarge),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(AppDimens.spacingMedium),
                              child: AnimatedBuilder(
                                animation: beamController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _RadarPainter(
                                      sweepAngle:
                                          beamController.value * 2 * math.pi,
                                      rssi: radarState.rssi,
                                      distanceMeters: radarState.distanceMeters,
                                      threatColor: threatColor,
                                      trend: radarState.trend,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bluetooth_searching_rounded,
                                            size: 28.w,
                                            color: threatColor,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '~${radarState.distanceMeters}m',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: threatColor,
                                                ),
                                          ),
                                          Text(
                                            '${radarState.rssi} dBm',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  fontFamily: 'monospace',
                                                  fontSize: 11.sp,
                                                  color: Colors.grey.shade600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Target Device Meta Info Card
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingMedium),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target Name',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                    Text(
                                      activeDevice.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'MAC Address',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                    Text(
                                      activeDevice.id,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Action Buttons
                        PrimaryButton(
                          label: 'Log Violation Incident',
                          onPressed: () {
                            context.push('/action/new', extra: activeDevice);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Displays Direction Triangulation Operating Guide Modal
  void _showDirectionGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.all(AppDimens.spacingLarge),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.explore_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direction Finding & Triangulation Guide',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ব্লুটুথ ডিভাইসের সঠিক দিক ও সীমানা খুঁজে বের করার নিয়ম',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _DirectionStepItem(
                    stepNumber: '1',
                    title: '১. হলের সাড়িতে হাঁটা শুরু করুন (Walking & Signal Direction)',
                    description:
                        'পরীক্ষা হলের কোনো একটি সারি ধরে সামনের দিকে হাঁটা শুরু করুন। অ্যাপের ওপরের ব্যানারটি লক্ষ্য করুন।',
                    icon: Icons.directions_walk_rounded,
                  ),
                  _DirectionStepItem(
                    stepNumber: '2',
                    title: '২. সিগন্যাল ডিরেকশন কালার বোঝা (Green vs Red vs Blue)',
                    description:
                        '• সবুজ (APPROACHING): সঠিক দিকে এগোচ্ছেন (দূরত্ব কমছে)।\n• লাল (RECEDING): ভুল দিকে যাচ্ছেন, উল্টো ঘুরে দাঁড়ান।\n• নীল (STATIONARY LOCK): আপনি বর্তমান দূরত্বে অবস্থান করছেন। এবার মোবাইলটি ডানে-বামে সুইপ করে নির্দিষ্ট বেঞ্চ নিশ্চিত করুন।',
                    icon: Icons.alt_route_rounded,
                  ),
                  _DirectionStepItem(
                    stepNumber: '3',
                    title: '৩. সঠিক সিট/পরীক্ষার্থী নিশ্চিতকরণ (Pinpoint Desk Location)',
                    description:
                        'যখন ডিস্ট্যান্স ~১.৫ মিটারের নিচে নামবে এবং সিগন্যাল CRITICAL (> -60 dBm) দেখাবে, তখন ডানে ও বামের সিটের দিকে ফোন এগিয়ে ধরুন। সবচেয়ে শক্তিশালী সিগন্যালের সিটটিই চূড়ান্ত থ্রেট।',
                    icon: Icons.pin_drop_rounded,
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  PrimaryButton(
                    label: 'Got it! Start Radar Guidance',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DirectionStepItem extends StatelessWidget {
  const _DirectionStepItem({
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
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
                    Icon(icon,
                        size: 16.w,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade800,
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

/// Custom painter for rendering concentric radar rings with meter labels, sweep beam, and proximity trend
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweepAngle,
    required this.rssi,
    required this.distanceMeters,
    required this.threatColor,
    required this.trend,
  });

  final double sweepAngle;
  final int rssi;
  final double distanceMeters;
  final Color threatColor;
  final ProximityTrend trend;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    final radii = [
      maxRadius * 0.25,
      maxRadius * 0.50,
      maxRadius * 0.75,
      maxRadius,
    ];

    final distanceLabels = ['1.5m', '3.0m', '4.5m', '6.0m+'];

    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];
      canvas.drawCircle(center, r, ringPaint);

      // Draw Distance Meter Labels on the radar map axis
      final textPainter = TextPainter(
        text: TextSpan(
          text: distanceLabels[i],
          style: TextStyle(
            color: Colors.teal.shade700,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + 4, center.dy - r - 12),
      );
    }

    // Draw crosshair axes
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Draw rotating radar sweep gradient arc
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          threatColor.withValues(alpha: 0.4),
          threatColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();

    // 5. Draw Dynamic Animated Red Target Dot & Tracking Laser Line
    final blipRatio = ((rssi + 100).clamp(0, 70) / 70.0).clamp(0.1, 0.9);
    final blipDistance = maxRadius * (1.0 - blipRatio);

    // Dynamically sweep blip position along with radar beam
    final blipAngle = sweepAngle - 0.35;
    final blipX = center.dx + blipDistance * math.cos(blipAngle);
    final blipY = center.dy + blipDistance * math.sin(blipAngle);

    final redColor = threatColor;

    // Draw animated connecting laser line from center to red target dot
    canvas.drawLine(
      center,
      Offset(blipX, blipY),
      Paint()
        ..color = redColor.withValues(alpha: 0.6)
        ..strokeWidth = 2.0,
    );

    // Outer pulsing red glow rings
    canvas.drawCircle(
      Offset(blipX, blipY),
      22.0,
      Paint()
        ..color = redColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(blipX, blipY),
      14.0,
      Paint()
        ..color = redColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Solid Inner Red Dot
    canvas.drawCircle(
      Offset(blipX, blipY),
      8.0,
      Paint()
        ..color = redColor
        ..style = PaintingStyle.fill,
    );

    // Center White Pin-point Dot
    canvas.drawCircle(
      Offset(blipX, blipY),
      3.0,
      Paint()..color = Colors.white,
    );

    // Prominent Red Target Distance Badge
    final blipTextPainter = TextPainter(
      text: TextSpan(
        text: ' 🔴 TARGET THREAT (${distanceMeters}m) ',
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Color(0xFFEF4444),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    blipTextPainter.layout();
    blipTextPainter.paint(
      canvas,
      Offset(blipX + 12, blipY - 12),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.rssi != rssi ||
        oldDelegate.distanceMeters != distanceMeters ||
        oldDelegate.trend != trend;
  }
}
