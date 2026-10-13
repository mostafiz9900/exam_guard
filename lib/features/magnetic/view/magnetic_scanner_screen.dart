import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view/widgets/guide_step_item.dart';
import 'package:exam_guard/features/magnetic/view/widgets/magnetic_gauge_painter.dart';
import 'package:exam_guard/features/magnetic/view/widgets/stat_item.dart';

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
      case MagneticHazardLevel.strongSource:
        return const Color(0xFFDC2626); // Alert Red
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(magneticViewModelProvider);
    final notifier = ref.read(magneticViewModelProvider.notifier);
    final hazardColor = _getHazardColor(state.hazardLevel);

    // Compute magnetic needle angle in radians
    final needleAngle = math.atan2(state.y, state.x);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPopBack) {
          context.popBack();
        } else {
          context.goTo(AppRoute.dashboard);
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
                          state.errorMessage != null
                              ? Icons.sensors_off_rounded
                              : Icons.sensors_rounded,
                          size: 16.w,
                          color: state.errorMessage != null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          state.errorMessage != null
                              ? 'SENSOR UNAVAILABLE'
                              : (state.isHardwareSensorActive
                                    ? 'MAGNETOMETER LIVE'
                                    : 'WAITING FOR SENSOR…'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: state.errorMessage != null
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
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
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.3),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
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
                              painter: MagneticGaugePainter(
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
                                            MagneticState.calculateHazard(
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
                                StatItem(
                                  label: 'Baseline',
                                  value: '${state.baseline} μT',
                                ),
                                StatItem(
                                  label: 'Peak Hold',
                                  value: '${state.peakValue} μT',
                                  valueColor: AppColors.error,
                                ),
                                StatItem(
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
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              onSelected: (_) => notifier.setSensitivity(sens),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingLarge),

                    // Action Buttons Row (Calibrate)
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
                      ],
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    // Log Incident Action Button
                    PrimaryButton(
                      label: 'Log Magnetic Incident',
                      onPressed: () {
                        context.pushTo(AppRoute.actionNew, extra: null);
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
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.12),
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
                  GuideStepItem(
                    stepNumber: '1',
                    title: 'কীভাবে স্ক্যান করবেন (How to Hold Device)',
                    description: 'আপনার মোবাইল ফোনটি পরীক্ষার্থীর জামা-কাপড়, পকেট, কলার, হাত বা পরীক্ষার বেঞ্চের ১ থেকে ৫ সেমি কাছে ধীরে ধীরে ঘোরাবেন। ফোনের ভেতরের Magnetometer সেন্সর ধাতু সনাক্ত করবে।',
                    icon: Icons.phonelink_ring_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '2',
                    title: 'Microtesla (μT) রিডিংয়ের অর্থ (Reading Values)',
                    description: '• 40 – 60 μT: স্বাভাবি পরিবেশ (কোনো মেটাল নেই)।\n• 70 – 90 μT: লুকানো মেটাল ইয়ারপিস, কাস্টম সার্কিট বা বেল্ট।\n• 100+ μT (CRITICAL): সক্রিয় স্মার্টফোন, স্মার্টওয়াচ বা উচ্চ ক্ষমতাসম্পন্ন ট্রান্সমিটার।',
                    icon: Icons.speed_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '3',
                    title: 'ক্যালিব্রেশন করার নিয়ম (Baseline Calibration)',
                    description: 'লোহার বেঞ্চ বা চেয়ারের সাধারণ মেটাল নয়েজ ফিল্টার করতে ফাঁকা জায়গায় ফোন ধরে "Calibrate Baseline" বাটনে চাপ দিন। এতে করে পরিবেশ অনুযায়ী সেন্সর রিরেসেট হয়ে সঠিক রিপোর্ট দেবে।',
                    icon: Icons.tune_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '4',
                    title: 'ঘটনা লগ করা (Log Incident)',
                    description: 'সন্দেহজনক কোনো মেটাল বা ডিভাইস পেলে ১-ক্লিকে "Log Magnetic Incident" বাটনে চেপে পরীক্ষার্থীর রুল সহ রিপোর্ট সাবমিট করুন।',
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
