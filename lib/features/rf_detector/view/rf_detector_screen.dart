import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/rf_detector/view_model/rf_detector_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/rf_detector/model/rf_threat_level.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/guide_step_tile.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_wave_painter.dart';

class RfDetectorScreen extends ConsumerWidget {
  const RfDetectorScreen({super.key});

  Color _getThreatColor(RfThreatLevel threat) {
    switch (threat) {
      case RfThreatLevel.quiet:
        return const Color(0xFF10B981); // Green
      case RfThreatLevel.moderate:
        return const Color(0xFFF59E0B); // Amber
      case RfThreatLevel.strong:
        return const Color(0xFFEF4444); // Red
    }
  }

  void _showOperatingGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'rf_guide_title'.tr(),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),

                GuideStepTile(
                  stepNumber: '1',
                  title: 'rf_guide_step1_title'.tr(),
                  description: 'rf_guide_step1_text'.tr(),
                ),
                SizedBox(height: 12.h),

                GuideStepTile(
                  stepNumber: '2',
                  title: 'rf_guide_step2_title'.tr(),
                  description: 'rf_guide_step2_text'.tr(),
                ),
                SizedBox(height: 12.h),

                GuideStepTile(
                  stepNumber: '3',
                  title: 'rf_guide_step3_title'.tr(),
                  description: 'rf_guide_step3_text'.tr(),
                ),
                SizedBox(height: 16.h),

                PrimaryButton(
                  label: 'rf_guide_done'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rfDetectorViewModelProvider);
    final notifier = ref.read(rfDetectorViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryText = colorScheme.onSurfaceVariant;
    final isMeasuring = state.isMeasuring;
    final themeColor = isMeasuring
        ? _getThreatColor(state.threatLevel)
        : colorScheme.outline;

    final summaryArgs = {
      'count': '${state.activeTransmitters}',
      'rate': '${state.packetsPerSecond}',
      'name': state.strongestSourceName ?? '',
    };
    final summary = state.strongestSourceName != null
        ? 'rf_summary_strongest'.tr(args: summaryArgs)
        : 'rf_summary'.tr(args: summaryArgs);

    Future<void> logIncident() async {
      notifier.setAlertsSuspended(true);
      await context.pushTo(
        AppRoute.actionNew,
        extra: ActionEntryArgs(
          category: 'RF Transmitter',
          notes: notifier.incidentNotes(),
        ),
      );
      if (context.mounted) notifier.setAlertsSuspended(false);
    }

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
          title: Text('rf_meter'.tr()),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showOperatingGuideModal(context),
              tooltip: 'rf_guide_title'.tr(),
            ),
            IconButton(
              icon: Icon(
                state.isBuzzerEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: state.isBuzzerEnabled ? themeColor : colorScheme.outline,
              ),
              onPressed: () => notifier.toggleBuzzer(),
              tooltip: 'rf_audio_tooltip'.tr(),
            ),
            const AppSettingsMenu(),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppDimens.spacingLarge),
                    child: Column(
                      children: [
                        // Header Hardware Status Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                            side: BorderSide(
                              color: themeColor.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingMedium),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.settings_input_antenna_rounded,
                                    color: themeColor,
                                    size: 24.w,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              state.hardwareNodeName ??
                                                  'rf_phone_radio'.tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.sp,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 3.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              (state.isHardwareNodeNearby
                                                      ? 'rf_badge_node'
                                                      : (isMeasuring
                                                            ? 'rf_badge_live'
                                                            : 'rf_badge_stopped'))
                                                  .tr(),
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        state.errorKey?.tr() ?? summary,
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: secondaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Circular Power Gauge Meter
                        Container(
                          width: 200.w,
                          height: 200.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeColor.withValues(alpha: 0.06),
                            border: Border.all(
                              color: themeColor.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeColor.withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                state.currentDbm?.toStringAsFixed(0) ?? '--',
                                style: TextStyle(
                                  fontSize: 34.sp,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'rf_strongest_signal'.tr(),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Text(
                                  'rf_peak'.tr(
                                    args: {
                                      'value':
                                          state.peakDbm?.toStringAsFixed(0) ??
                                          '--',
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Hazard Banner Card
                        Card(
                          elevation: 2,
                          color: themeColor.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                            side: BorderSide(
                              color: themeColor.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingMedium),
                            child: Column(
                              children: [
                                Text(
                                  isMeasuring
                                      ? state.threatLevel.labelKey.tr()
                                      : (state.isStarting
                                            ? 'rf_starting'.tr()
                                            : 'rf_not_measuring'.tr(
                                                args: {
                                                  'reason':
                                                      (state.errorKey ??
                                                              'rf_reason_stopped')
                                                          .tr(),
                                                },
                                              )),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: themeColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  (isMeasuring
                                          ? state.threatLevel.suggestionKey
                                          : (state.isBluetoothOff
                                                ? 'rf_bluetooth_off_hint'
                                                : 'rf_not_measuring_hint'))
                                      .tr(),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: secondaryText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (!isMeasuring && !state.isStarting) ...[
                                  SizedBox(height: 8.h),
                                  OutlinedButton.icon(
                                    onPressed: notifier.startScanning,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text('rf_retry'.tr()),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // RF Waveform Sparkline Chart
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingMedium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'rf_history_title'.tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      (isMeasuring
                                              ? 'rf_history_live'
                                              : 'rf_history_stopped')
                                          .tr(),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: themeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                SizedBox(
                                  height: 90.h,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: RfWavePainter(
                                      history: state.history,
                                      color: themeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        OutlinedButton.icon(
                          onPressed: () => notifier.resetPeak(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('rf_reset_peak'.tr()),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        PrimaryButton(
                          label: 'log_incident'.tr(),
                          onPressed: logIncident,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
