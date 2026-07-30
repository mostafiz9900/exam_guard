import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/rf_detector_provider.dart';

class RfDetectorScreen extends ConsumerWidget {
  const RfDetectorScreen({super.key});

  Color _getThreatColor(RfThreatLevel threat) {
    switch (threat) {
      case RfThreatLevel.ambient:
        return const Color(0xFF10B981); // Green
      case RfThreatLevel.elevated:
        return const Color(0xFFF59E0B); // Amber
      case RfThreatLevel.criticalCall:
        return const Color(0xFFEF4444); // Red
      case RfThreatLevel.criticalData:
        return const Color(0xFFDC2626); // Dark Red
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
                      'ESP32 Cellular RF Operating Guide',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),

                _GuideStepTile(
                  stepNumber: '1',
                  title: 'Wideband RF Spectrum Capture (1MHz - 8GHz)',
                  description:
                      'AD8318 sensor measures raw electromagnetic radio power in dBm. Detects GSM calls (900/1800MHz), 3G (2100MHz), 4G LTE (2300MHz) and 5G Sub-6GHz (3500MHz).',
                ),
                SizedBox(height: 12.h),

                _GuideStepTile(
                  stepNumber: '2',
                  title: 'Detecting Active SIM Voice Calls 📞',
                  description:
                      'When candidate makes or receives a phone call, RF power surges above -48 dBm. The app triggers RED alert and rapid Geiger beeping.',
                ),
                SizedBox(height: 12.h),

                _GuideStepTile(
                  stepNumber: '3',
                  title: 'Detecting 4G/5G Cellular Data Packets 📶',
                  description:
                      'Active internet browsing or sending exam questions creates high-density packet bursts. Sweep phone near candidate desk to pinpoint source.',
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
    final state = ref.watch(rfDetectorProvider);
    final notifier = ref.read(rfDetectorProvider.notifier);
    final themeColor = _getThreatColor(state.threatLevel);

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
          title: const Text('ESP32 Cellular RF Analyzer'),
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
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
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
                                              'ESP32-S3 + AD8318 Module',
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
                                              color: (state.isHardwareConnected
                                                      ? AppColors.success
                                                      : Colors.blue)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              state.isHardwareConnected
                                                  ? 'HARDWARE BLE'
                                                  : 'SIMULATOR ACTIVE',
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold,
                                                color: state.isHardwareConnected
                                                    ? AppColors.success
                                                    : Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        '1 MHz – 8.0 GHz Wideband RF Detector • ${state.activeBand}',
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
                                '${state.currentDbm}',
                                style: TextStyle(
                                  fontSize: 34.sp,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'dBm RF POWER',
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
                                  'Peak: ${state.peakDbm} dBm',
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
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
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
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
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
                                      'RF Spectrum Waveform (-90 to -20 dBm)',
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
                                    painter: _RfWavePainter(
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

                        // Hardware Testing Deck Buttons (For simulation & verification)
                        Text(
                          'Hardware Test & Simulation Deck',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
                                ),
                                onPressed: () =>
                                    notifier.triggerSimulatedCallSpike(),
                                icon: Icon(Icons.call_rounded, size: 16.w),
                                label: Text(
                                  'Test SIM Call Spike',
                                  style: TextStyle(fontSize: 10.sp),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
                                ),
                                onPressed: () =>
                                    notifier.triggerSimulatedDataBurst(),
                                icon: Icon(Icons.wifi_tethering_rounded,
                                    size: 16.w),
                                label: Text(
                                  'Test 5G Data Burst',
                                  style: TextStyle(fontSize: 10.sp),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        OutlinedButton.icon(
                          onPressed: () => notifier.resetPeak(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Peak RF Level'),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        PrimaryButton(
                          label: 'Log Violation Incident Report',
                          onPressed: () {
                            context.push('/action/new');
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

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12.r,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            stepNumber,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RfWavePainter extends CustomPainter {
  _RfWavePainter({required this.history, required this.color});
  final List<double> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final dbm = history[i].clamp(-90.0, -20.0);
      final norm = (dbm - (-90.0)) / 70.0; // 0.0 to 1.0
      final y = size.height - (norm * size.height);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RfWavePainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.color != color;
  }
}
