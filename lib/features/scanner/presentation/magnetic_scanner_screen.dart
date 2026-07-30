import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/magnetic_scanner_provider.dart';

class MagneticScannerScreen extends ConsumerWidget {
  const MagneticScannerScreen({super.key});

  Color _getHazardColor(MagneticHazardLevel level) {
    switch (level) {
      case MagneticHazardLevel.normal:
        return const Color(0xFF10B981); // Green
      case MagneticHazardLevel.elevated:
        return const Color(0xFFF59E0B); // Yellow
      case MagneticHazardLevel.critical:
        return const Color(0xFFEF4444); // Red
      case MagneticHazardLevel.cellCallDetected:
        return const Color(0xFFDC2626); // Alert Red
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(magneticScannerProvider);
    final notifier = ref.read(magneticScannerProvider.notifier);
    final hazardColor = _getHazardColor(state.hazardLevel);

    // Compute magnetic needle angle in radians
    final needleAngle = math.atan2(state.y, state.x);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text('magnetic_scanner'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, size: 24.w),
            tooltip: 'User Guide & Instructions',
            onPressed: () => _showHowToUseModal(context),
          ),
          IconButton(
            icon: Icon(
              state.isBuzzerEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 24.w,
            ),
            tooltip: 'Toggle Audio Buzzer',
            onPressed: () => notifier.toggleBuzzer(),
          ),
          IconButton(
            icon: Icon(
              state.isScanning
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow_rounded,
              size: 28.w,
            ),
            tooltip: state.isScanning ? 'Pause Sensor' : 'Resume Sensor',
            onPressed: () {
              if (state.isScanning) {
                notifier.stopScanning();
              } else {
                notifier.startScanning();
              }
            },
          ),
          const AppSettingsMenu(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Sensor Engine Status & Guide Action Button
                  Row(
                    children: [
                      Icon(
                        state.isHardwareSensorActive
                            ? Icons.sensors_rounded
                            : Icons.tune_rounded,
                        size: 16.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        state.isHardwareSensorActive
                            ? 'MAGNETOMETER ONLINE'
                            : 'SENSOR ENGINE ACTIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showHowToUseModal(context),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 14.w,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'How to Use',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Hazard Status Banner
                  Container(
                    padding: EdgeInsets.all(AppDimens.spacingMedium),
                    decoration: BoxDecoration(
                      color: hazardColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMedium,
                      ),
                      border: Border.all(
                        color: hazardColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.hazardLevel == MagneticHazardLevel.normal
                              ? Icons.verified_user_rounded
                              : Icons.warning_amber_rounded,
                          color: hazardColor,
                          size: 28.w,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.hazardLevel.label,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: hazardColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                state.hazardLevel.suggestion,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Main Interactive Compass Radial Gauge
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusLarge,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.spacingLarge),
                      child: Column(
                        children: [
                          Text(
                            'MAGNETIC INTENSITY GAUGE',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  letterSpacing: 1.2,
                                  color: Colors.grey,
                                ),
                          ),
                          SizedBox(height: 16.h),

                          // Radial Gauge Custom Painter
                          CustomPaint(
                            size: Size(180.w, 180.w),
                            painter: _MagneticGaugePainter(
                              magnitude: state.magnitude,
                              angle: needleAngle,
                              color: hazardColor,
                            ),
                            child: SizedBox(
                              width: 180.w,
                              height: 180.w,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${state.magnitude}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: hazardColor,
                                          ),
                                    ),
                                    Text(
                                      'μT (Microtesla)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontSize: 10.sp,
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // Live Signal History Sparkline Wave
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Field Fluctuations',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                              SizedBox(height: 6.h),
                              SizedBox(
                                height: 36.h,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: state.history.map((val) {
                                    final normalized = (val / 160.0).clamp(
                                      0.1,
                                      1.0,
                                    );
                                    return Container(
                                      width: 14.w,
                                      height: 36.h * normalized,
                                      decoration: BoxDecoration(
                                        color: _getHazardColor(
                                          MagneticScannerState.calculateHazard(
                                            val,
                                            state.baseline,
                                            state.sensitivity,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),

                          // Baseline & Peak Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                label: 'Baseline',
                                value: '${state.baseline} μT',
                              ),
                              _StatItem(
                                label: 'Peak Hold',
                                value: '${state.peakValue} μT',
                                valueColor: AppColors.error,
                              ),
                              _StatItem(
                                label: 'Vector (X/Y/Z)',
                                value:
                                    '${state.x.toInt()}/${state.y.toInt()}/${state.z.toInt()}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Sensitivity Presets Selector
                  Text(
                    'Detection Sensitivity Preset',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: MagneticSensitivity.values.map((sens) {
                        final isSelected = state.sensitivity == sens;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(sens.label),
                            selected: isSelected,
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            onSelected: (_) => notifier.setSensitivity(sens),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Action Buttons Row (Calibrate & Test Trigger)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            notifier.calibrateBaseline();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Baseline calibrated to ambient environment',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Calibrate Baseline'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            notifier.triggerSimulatedMetalAnomaly();
                          },
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text('Simulate Metal Test'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  // Log Incident Action Button
                  PrimaryButton(
                    label: 'Log Magnetic Incident',
                    onPressed: () {
                      context.push('/action/new', extra: null);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  /// Displays step-by-step user operating guide modal
  void _showHowToUseModal(BuildContext context) {
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
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
                              'Magnetic Scanner Operating Guide',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'পরীক্ষা হলে ম্যাগনেটিক স্ক্যানার ব্যবহারের নির্দেশিকা',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _GuideStepItem(
                    stepNumber: '1',
                    title: 'কীভাবে স্ক্যান করবেন (How to Hold Device)',
                    description:
                        'আপনার মোবাইল ফোনটি পরীক্ষার্থীর জামা-কাপড়, পকেট, কলার, হাত বা পরীক্ষার বেঞ্চের ১ থেকে ৫ সেমি কাছে ধীরে ধীরে ঘোরাবেন। ফোনের ভেতরের Magnetometer সেন্সর ধাতু সনাক্ত করবে।',
                    icon: Icons.phonelink_ring_rounded,
                  ),
                  _GuideStepItem(
                    stepNumber: '2',
                    title: 'Microtesla (μT) রিডিংয়ের অর্থ (Reading Values)',
                    description:
                        '• 40 – 60 μT: স্বাভাবি পরিবেশ (কোনো মেটাল নেই)।\n• 70 – 90 μT: লুকানো মেটাল ইয়ারপিস, কাস্টম সার্কিট বা বেল্ট।\n• 100+ μT (CRITICAL): সক্রিয় স্মার্টফোন, স্মার্টওয়াচ বা উচ্চ ক্ষমতাসম্পন্ন ট্রান্সমিটার।',
                    icon: Icons.speed_rounded,
                  ),
                  _GuideStepItem(
                    stepNumber: '3',
                    title: 'ক্যালিব্রেশন করার নিয়ম (Baseline Calibration)',
                    description:
                        'লোহার বেঞ্চ বা চেয়ারের সাধারণ মেটাল নয়েজ ফিল্টার করতে ফাঁকা জায়গায় ফোন ধরে "Calibrate Baseline" বাটনে চাপ দিন। এতে করে পরিবেশ অনুযায়ী সেন্সর রিরেসেট হয়ে সঠিক রিপোর্ট দেবে।',
                    icon: Icons.tune_rounded,
                  ),
                  _GuideStepItem(
                    stepNumber: '4',
                    title: 'ঘটনা লগ করা (Log Incident)',
                    description:
                        'সন্দেহজনক কোনো মেটাল বা ডিভাইস পেলে ১-ক্লিকে "Log Magnetic Incident" বাটনে চেপে পরীক্ষার্থীর রুল সহ রিপোর্ট সাবমিট করুন।',
                    icon: Icons.report_problem_rounded,
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  PrimaryButton(
                    label: 'Got it! Start Scanning',
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

class _GuideStepItem extends StatelessWidget {
  const _GuideStepItem({
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
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
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
class _MagneticGaugePainter extends CustomPainter {
  _MagneticGaugePainter({
    required this.magnitude,
    required this.angle,
    required this.color,
  });

  final double magnitude;
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 8, bgPaint);

    // Active magnitude arc
    final activeRatio = (magnitude / 180.0).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -math.pi / 2,
      2 * math.pi * activeRatio,
      false,
      activePaint,
    );

    // Rotating Needle indicator
    final needleLength = radius - 24;
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final endX = center.dx + needleLength * math.cos(angle);
    final endY = center.dy + needleLength * math.sin(angle);

    canvas.drawLine(center, Offset(endX, endY), needlePaint);
    canvas.drawCircle(center, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MagneticGaugePainter oldDelegate) {
    return oldDelegate.magnitude != magnitude || oldDelegate.angle != angle;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
