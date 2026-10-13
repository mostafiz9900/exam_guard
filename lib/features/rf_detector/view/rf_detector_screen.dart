import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/rf_detector/view_model/rf_detector_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
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
                      'RF Activity Meter Guide',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),

                GuideStepTile(
                  stepNumber: '1',
                  title: 'What this meter measures',
                  description: 'Live 2.4 GHz Bluetooth transmissions received by this phone, in dBm. It shows the strongest nearby transmitter, packets per second and how many devices are transmitting. A phone cannot measure cellular (SIM) signals directly.',
                ),
                SizedBox(height: 12.h),

                GuideStepTile(
                  stepNumber: '2',
                  title: 'Finding a hidden transmitter 📍',
                  description: 'Walk slowly between desks. Above -50 dBm the transmitter is within about 1 metre: the meter turns red and beeps.',
                ),
                SizedBox(height: 12.h),

                GuideStepTile(
                  stepNumber: '3',
                  title: 'ESP32 hardware node 📡',
                  description: 'If an ExamGuard ESP32 node is powered on nearby, its badge turns green. The node is detected by its Bluetooth name (examguard / esp32 / rf-node).',
                ),
                SizedBox(height: 16.h),

                PrimaryButton(
                  label: 'Got It / Continue Monitoring',
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
    final themeColor = _getThreatColor(state.threatLevel);

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
          title: const Text('Live RF Activity Meter'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showOperatingGuideModal(context),
              tooltip: 'Operating Guide',
            ),
            IconButton(
              icon: Icon(
                state.isBuzzerEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: state.isBuzzerEnabled ? themeColor : Colors.grey,
              ),
              onPressed: () => notifier.toggleBuzzer(),
              tooltip: 'Geiger Audio Beep',
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
                                                  'Phone Bluetooth radio',
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
                                              color:
                                                  (state.isHardwareNodeNearby
                                                          ? AppColors.success
                                                          : Colors.blue)
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              state.isHardwareNodeNearby
                                                  ? 'ESP32 NODE NEARBY'
                                                  : (state.isScanning
                                                        ? 'LIVE'
                                                        : 'STOPPED'),
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    state.isHardwareNodeNearby
                                                    ? AppColors.success
                                                    : Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        state.errorMessage ??
                                            '${state.activeTransmitters} transmitters • ${state.packetsPerSecond} packets/s'
                                                '${state.strongestSourceName != null ? ' • strongest: ${state.strongestSourceName}' : ''}',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Colors.grey.shade600,
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
                                'dBm STRONGEST SIGNAL',
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
                                  'Peak: ${state.peakDbm?.toStringAsFixed(0) ?? '--'} dBm',
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
                                  state.threatLevel.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: themeColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  state.threatLevel.suggestion,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
                                    Text(
                                      '2.4 GHz Signal History (-100 to -20 dBm)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                    Text(
                                      'Live Stream',
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
                          label: const Text('Reset Peak'),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        PrimaryButton(
                          label: 'Log Violation Incident Report',
                          onPressed: () {
                            context.pushTo(AppRoute.actionNew);
                          },
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
