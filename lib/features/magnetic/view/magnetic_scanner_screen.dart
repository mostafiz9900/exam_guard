import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view/widgets/guide_step_item.dart';
import 'package:exam_guard/features/magnetic/view/widgets/magnetic_gauge_painter.dart';
import 'package:exam_guard/features/magnetic/view/widgets/stat_item.dart';

class MagneticScannerScreen extends HookConsumerWidget {
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

  static String _threshold(MagneticSensitivity s) =>
      s.threshold.toStringAsFixed(0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(magneticViewModelProvider);
    final notifier = ref.read(magneticViewModelProvider.notifier);

    // Audio alerts play only while this screen is open.
    useEffect(() {
      notifier.setScreenVisible(true);
      return () => notifier.setScreenVisible(false);
    }, [notifier]);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryText = colorScheme.onSurfaceVariant;
    final isLive = state.isLive;
    final isStopped = !state.isScanning || state.errorKey != null;
    final hazardColor = isLive
        ? _getHazardColor(state.hazardLevel)
        : colorScheme.outline;

    final String statusText;
    final Color statusColor;
    if (state.errorKey != null) {
      statusText = 'mag_status_unavailable'.tr();
      statusColor = colorScheme.error;
    } else if (!state.isScanning) {
      statusText = 'mag_status_paused'.tr();
      statusColor = colorScheme.outline;
    } else if (!state.isHardwareSensorActive) {
      statusText = 'mag_status_waiting'.tr();
      statusColor = colorScheme.outline;
    } else {
      statusText = 'mag_status_live'.tr();
      statusColor = colorScheme.primary;
    }

    final String bannerTitle;
    final String bannerText;
    if (isLive) {
      bannerTitle = state.hazardLevel.labelKey.tr();
      bannerText = state.hazardLevel.suggestionKey.tr();
    } else if (isStopped) {
      bannerTitle = 'mag_not_measuring'.tr(
        args: {'reason': (state.errorKey ?? 'mag_reason_paused').tr()},
      );
      bannerText = 'mag_not_measuring_text'.tr();
    } else {
      bannerTitle = 'mag_status_waiting'.tr();
      bannerText = 'mag_waiting_text'.tr();
    }

    void calibrate() {
      final ok = notifier.calibrateBaseline();
      final latest = ref.read(magneticViewModelProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'mag_baseline_set'.tr(
                    args: {'value': latest.baseline.toStringAsFixed(1)},
                  )
                : 'mag_not_calibrated'.tr(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Future<void> logIncident() async {
      notifier.setAlertsSuspended(true);
      await context.pushTo(
        AppRoute.actionNew,
        extra: ActionEntryArgs(
          category: 'Magnetic Anomaly',
          notes: notifier.incidentNotes(),
        ),
      );
      if (context.mounted) notifier.setAlertsSuspended(false);
    }

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
              tooltip: 'mag_how_to_use'.tr(),
              onPressed: () => _showHowToUseModal(context),
            ),
            IconButton(
              icon: Icon(
                state.isBuzzerEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                size: 24.w,
              ),
              tooltip: 'mag_audio_tooltip'.tr(),
              onPressed: () => notifier.toggleBuzzer(),
            ),
            IconButton(
              icon: Icon(
                state.isScanning
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded,
                size: 28.w,
              ),
              tooltip: (state.isScanning ? 'mag_pause' : 'mag_resume').tr(),
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
                          isLive
                              ? Icons.sensors_rounded
                              : Icons.sensors_off_rounded,
                          size: 16.w,
                          color: statusColor,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: statusColor,
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
                                  'mag_how_to_use'.tr(),
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
                            !isLive
                                ? Icons.sensors_off_rounded
                                : (state.hazardLevel ==
                                          MagneticHazardLevel.normal
                                      ? Icons.verified_user_rounded
                                      : Icons.warning_amber_rounded),
                            color: hazardColor,
                            size: 28.w,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bannerTitle,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: hazardColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  bannerText,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: secondaryText),
                                ),
                              ],
                            ),
                          ),
                          if (isStopped) ...[
                            SizedBox(width: 8.w),
                            OutlinedButton(
                              onPressed: notifier.startScanning,
                              child: Text('mag_retry'.tr()),
                            ),
                          ],
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
                              'mag_gauge_title'.tr(),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    letterSpacing: 1.2,
                                    color: secondaryText,
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
                                trackColor: colorScheme.surfaceContainerHighest,
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
                                        'mag_unit'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontSize: 10.sp,
                                              color: secondaryText,
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
                                  'mag_fluctuations'.tr(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: secondaryText),
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
                                          color: isLive
                                              ? _getHazardColor(
                                                  MagneticState.calculateHazard(
                                                    val,
                                                    state.baseline,
                                                    state.sensitivity,
                                                  ),
                                                )
                                              : colorScheme.outline,
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
                                  label:
                                      (state.isBaselineCalibrated
                                              ? 'mag_baseline'
                                              : 'mag_baseline_auto')
                                          .tr(),
                                  value: '${state.baseline} μT',
                                ),
                                StatItem(
                                  label: 'mag_peak_hold'.tr(),
                                  value: '${state.peakValue} μT',
                                  valueColor: AppColors.error,
                                ),
                                StatItem(
                                  label: 'mag_vector'.tr(),
                                  value:
                                      '${state.x.toInt()}/${state.y.toInt()}/${state.z.toInt()}',
                                ),
                              ],
                            ),
                            if (isLive && !state.isBaselineCalibrated) ...[
                              SizedBox(height: 8.h),
                              Text(
                                'mag_baseline_auto_hint'.tr(
                                  args: {'button': 'mag_calibrate'.tr()},
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: secondaryText),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingLarge),

                    // Sensitivity Presets Selector
                    Text(
                      'mag_sensitivity_title'.tr(),
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
                            padding: EdgeInsetsDirectional.only(end: 8.w),
                            child: ChoiceChip(
                              label: Text(
                                'mag_sensitivity_chip'.tr(
                                  args: {
                                    'label': sens.labelKey.tr(),
                                    'value': _threshold(sens),
                                  },
                                ),
                              ),
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
                    SizedBox(height: 4.h),
                    Text(
                      'mag_sensitivity_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: secondaryText),
                    ),
                    SizedBox(height: AppDimens.spacingLarge),

                    // Action Buttons Row (Calibrate)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLive ? calibrate : null,
                            icon: const Icon(Icons.tune_rounded),
                            label: Text('mag_calibrate'.tr()),
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
                      label: 'log_incident'.tr(),
                      onPressed: logIncident,
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
                              'mag_guide_title'.tr(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'mag_guide_subtitle'.tr(),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  GuideStepItem(
                    stepNumber: '1',
                    title: 'mag_guide_step1_title'.tr(),
                    description: 'mag_guide_step1_text'.tr(),
                    icon: Icons.phonelink_ring_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '2',
                    title: 'mag_guide_step2_title'.tr(),
                    description: 'mag_guide_step2_text'.tr(
                      args: {
                        'low': _threshold(MagneticSensitivity.low),
                        'medium': _threshold(MagneticSensitivity.medium),
                        'high': _threshold(MagneticSensitivity.high),
                      },
                    ),
                    icon: Icons.speed_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '3',
                    title: 'mag_guide_step3_title'.tr(),
                    description: 'mag_guide_step3_text'.tr(
                      args: {'button': 'mag_calibrate'.tr()},
                    ),
                    icon: Icons.tune_rounded,
                  ),
                  GuideStepItem(
                    stepNumber: '4',
                    title: 'mag_guide_step4_title'.tr(),
                    description: 'mag_guide_step4_text'.tr(
                      args: {'button': 'log_incident'.tr()},
                    ),
                    icon: Icons.report_problem_rounded,
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  PrimaryButton(
                    label: 'mag_guide_done'.tr(),
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
