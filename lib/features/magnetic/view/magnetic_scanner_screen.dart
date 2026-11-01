import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/widgets/app_bottom_sheet.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view/widgets/guide_step_item.dart';
import 'package:exam_guard/features/magnetic/view/widgets/magnetic_dial.dart';

class MagneticScannerScreen extends HookConsumerWidget {
  const MagneticScannerScreen({super.key});

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
    final isLive = state.isLive;
    final isUnavailable = state.isSensorUnavailable;

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

    final gap = SizedBox(height: AppDimens.spacingMedium);
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
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'mag_how_to_use'.tr(),
              onPressed: () => _showHowToUseModal(context),
            ),
            if (!isUnavailable)
              IconButton(
                icon: Icon(
                  state.isBuzzerEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
                tooltip: 'mag_audio_tooltip'.tr(),
                onPressed: notifier.toggleBuzzer,
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimens.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusHeader(state: state, onPause: notifier.stopScanning),
                    gap,
                    if (state.needsCalibration) ...[
                      const _CompassCalibration(),
                      gap,
                    ],
                    if (isUnavailable)
                      _NoSensorCard(
                        onRetry: notifier.startScanning,
                        onOpenScanner: () => context.pushTo(AppRoute.scanner),
                      )
                    else ...[
                      _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MagneticDial(state: state),
                            SizedBox(height: AppDimens.spacingMedium),
                            _Stats(state: state),
                            if (state.isRawSensor) ...[
                              SizedBox(height: AppDimens.spacingSmall),
                              Text(
                                'mag_raw_sensor_note'.tr(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      gap,
                      if (isLive)
                        _Guidance(level: state.hazardLevel)
                      else
                        _NotMeasuring(
                          state: state,
                          onResume: notifier.startScanning,
                        ),
                      gap,
                      _Panel(
                        child: _ZeroAndSensitivity(
                          state: state,
                          onSetZero: isLive ? calibrate : null,
                          onSensitivity: notifier.setSensitivity,
                        ),
                      ),
                      gap,
                      _Panel(child: _ChangeChart(state: state)),
                      SizedBox(height: AppDimens.spacingLarge),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: logIncident,
                          icon: const Icon(Icons.report_rounded),
                          label: Text('log_incident'.tr()),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowToUseModal(BuildContext context) {
    showAppBottomSheet(
      context: context,
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

/// Shown instead of the gauge and controls when the phone has no
/// magnetometer: nothing on this screen can work, so say so plainly.
class _NoSensorCard extends StatelessWidget {
  const _NoSensorCard({required this.onRetry, required this.onOpenScanner});

  /// A stream error stops the sensor; this restarts it.
  final VoidCallback onRetry;
  final VoidCallback onOpenScanner;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sensors_off_rounded,
                size: 40.w,
                color: colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppDimens.spacingMedium),
            Text(
              'mag_no_sensor_title'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            Text(
              'mag_no_sensor_text'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            SizedBox(height: AppDimens.spacingLarge),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppDimens.spacingSmall,
              runSpacing: AppDimens.spacingSmall,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('mag_retry'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenScanner,
                  icon: const Icon(Icons.cell_wifi_rounded),
                  label: Text('wireless_scanner'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain bordered surface (no shadow).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Sensor line with LIVE / PAUSED / WAITING / UNAVAILABLE and Pause.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state, required this.onPause});

  final MagneticState state;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (String key, Color color) = state.isSensorUnavailable
        ? ('mag_status_unavailable', colors.onSurfaceVariant)
        : !state.isScanning
        ? ('mag_status_paused', colors.outline)
        : !state.isLive
        ? ('mag_status_waiting', colors.outline)
        : ('mag_status_live', MagColors.normal);
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.explore_outlined, color: color, size: 20.w),
        ),
        SizedBox(width: AppDimens.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'mag_sensor_name'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                key.tr(),
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (state.isScanning && !state.isSensorUnavailable)
          IconButton.filledTonal(
            tooltip: 'mag_pause'.tr(),
            icon: const Icon(Icons.pause_rounded),
            onPressed: onPause,
          ),
      ],
    );
  }
}

/// iOS asks for its compass to be calibrated: figure-8 prompt.
class _CompassCalibration extends StatelessWidget {
  const _CompassCalibration();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const color = MagColors.elevated;
    return Container(
      key: const Key('mag_compass_calibration'),
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.all_inclusive_rounded, color: color),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'mag_figure8_title'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('mag_figure8_text'.tr(), style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Change now · normal level · strongest change.
class _Stats extends StatelessWidget {
  const _Stats({required this.state});

  final MagneticState state;

  @override
  Widget build(BuildContext context) {
    final live = state.isLive;
    String ut(double v) => '${v.toStringAsFixed(0)} μT';
    // Labels may wrap to two lines; keep the three tiles the same height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stat(
            icon: Icons.trending_up_rounded,
            value: live ? ut(state.change) : '--',
            label: 'mag_stat_change'.tr(),
          ),
          SizedBox(width: 8.w),
          _Stat(
            icon: Icons.horizontal_rule_rounded,
            value: live ? ut(state.baseline) : '--',
            label:
                (state.isBaselineCalibrated
                        ? 'mag_stat_zero_set'
                        : 'mag_stat_zero_auto')
                    .tr(),
          ),
          SizedBox(width: 8.w),
          _Stat(
            icon: Icons.flag_outlined,
            value: live ? ut(state.peakChange) : '--',
            label: 'mag_stat_peak'.tr(),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16.w, color: colors.primary),
            SizedBox(height: 2.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the reading means and what to do now.
class _Guidance extends StatelessWidget {
  const _Guidance({required this.level});

  final MagneticHazardLevel level;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = MagColors.of(level);
    final icon = switch (level) {
      MagneticHazardLevel.normal => Icons.check_circle_outline_rounded,
      MagneticHazardLevel.elevated => Icons.search_rounded,
      MagneticHazardLevel.critical ||
      MagneticHazardLevel.strongSource => Icons.warning_amber_rounded,
    };
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26.w),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.labelKey.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(level.suggestionKey.tr(), style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paused or starting: never an all-clear.
class _NotMeasuring extends StatelessWidget {
  const _NotMeasuring({required this.state, required this.onResume});

  final MagneticState state;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final paused = !state.isScanning;
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            paused
                ? 'mag_not_measuring'.tr(
                    args: {'reason': 'mag_reason_paused'.tr()},
                  )
                : 'mag_status_waiting'.tr(),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4.h),
          Text(
            paused ? 'mag_not_measuring_text'.tr() : 'mag_waiting_text'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (paused) ...[
            SizedBox(height: AppDimens.spacingSmall),
            OutlinedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('mag_resume'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Set zero here" and the sensitivity choice.
class _ZeroAndSensitivity extends StatelessWidget {
  const _ZeroAndSensitivity({
    required this.state,
    required this.onSetZero,
    required this.onSensitivity,
  });

  final MagneticState state;
  final VoidCallback? onSetZero;
  final ValueChanged<MagneticSensitivity> onSensitivity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hint = textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: onSetZero,
          icon: const Icon(Icons.adjust_rounded),
          label: Text('mag_calibrate'.tr()),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
        SizedBox(height: 4.h),
        Text(
          state.isBaselineCalibrated
              ? 'mag_zero_hint_set'.tr()
              : 'mag_baseline_auto_hint'.tr(
                  args: {'button': 'mag_calibrate'.tr()},
                ),
          style: hint,
        ),
        SizedBox(height: AppDimens.spacingMedium),
        Text(
          'mag_sensitivity_title'.tr(),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        SegmentedButton<MagneticSensitivity>(
          showSelectedIcon: false,
          segments: [
            for (final s in MagneticSensitivity.values)
              ButtonSegment(
                value: s,
                label: Text('mag_level_short_${s.name}'.tr()),
              ),
          ],
          selected: {state.sensitivity},
          onSelectionChanged: (v) => onSensitivity(v.first),
        ),
        SizedBox(height: 4.h),
        Text(
          'mag_sensitivity_now'.tr(
            args: {'value': state.sensitivity.threshold.toStringAsFixed(0)},
          ),
          style: hint,
        ),
      ],
    );
  }
}

/// Change from normal over the last readings, over the hazard zones.
class _ChangeChart extends StatelessWidget {
  const _ChangeChart({required this.state});

  final MagneticState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = state.isLive
        ? MagColors.of(state.hazardLevel)
        : colors.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'mag_fluctuations'.tr(),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        SizedBox(
          height: 90.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            child: CustomPaint(
              painter: _ChangeChartPainter(
                changes: [
                  for (final m in state.history) (m - state.baseline).abs(),
                ],
                threshold: state.sensitivity.threshold,
                color: color,
                dim: !state.isLive,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'mag_chart_hint'.tr(),
          style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ChangeChartPainter extends CustomPainter {
  _ChangeChartPainter({
    required this.changes,
    required this.threshold,
    required this.color,
    required this.dim,
  });

  final List<double> changes;
  final double threshold;
  final Color color;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final top = MagneticDial.scale * threshold;
    double y(double v) => size.height - (v / top).clamp(0.0, 1.0) * size.height;
    final alpha = dim ? 0.05 : 0.12;
    void band(double from, double to, Color c) => canvas.drawRect(
      Rect.fromLTRB(0, y(to), size.width, y(from)),
      Paint()..color = c.withValues(alpha: alpha),
    );
    band(0, threshold, MagColors.normal);
    band(threshold, 2 * threshold, MagColors.elevated);
    band(2 * threshold, 4 * threshold, MagColors.critical);
    band(4 * threshold, top, MagColors.strong);
    if (changes.length < 2) return;
    final step = size.width / (changes.length - 1);
    final path = Path();
    for (var i = 0; i < changes.length; i++) {
      final p = Offset(i * step, y(changes[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChangeChartPainter old) =>
      old.changes != changes || old.color != color || old.dim != dim;
}
