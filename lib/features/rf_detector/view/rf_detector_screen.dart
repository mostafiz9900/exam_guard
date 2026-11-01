import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/widgets/app_bottom_sheet.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/rf_detector/view_model/rf_detector_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/rf_detector/model/rf_threat_level.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/guide_step_tile.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_dial.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_history_chart.dart';

class RfDetectorScreen extends ConsumerWidget {
  const RfDetectorScreen({super.key});

  Color _getThreatColor(RfThreatLevel threat) => RfColors.of(threat);

  void _showOperatingGuideModal(BuildContext context) {
    showAppBottomSheet(
      context: context,
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
    final isMeasuring = state.isMeasuring;
    final themeColor = isMeasuring
        ? _getThreatColor(state.threatLevel)
        : colorScheme.outline;

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
              ),
              onPressed: () => notifier.toggleBuzzer(),
              tooltip: 'rf_audio_tooltip'.tr(),
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
                    _StatusHeader(state: state, color: themeColor),
                    gap,
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RfDial(
                            dbm: state.currentDbm,
                            level: state.threatLevel,
                            isMeasuring: isMeasuring,
                          ),
                          SizedBox(height: AppDimens.spacingMedium),
                          _Stats(state: state),
                          if (isMeasuring &&
                              state.strongestSourceName != null) ...[
                            SizedBox(height: AppDimens.spacingSmall),
                            Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 16.w,
                                  color: themeColor,
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    'rf_strongest_source'.tr(
                                      args: {
                                        'name': state.strongestSourceName!,
                                      },
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: isMeasuring
                                  ? notifier.resetPeak
                                  : null,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text('rf_reset_peak'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    gap,
                    if (isMeasuring)
                      _Guidance(level: state.threatLevel, color: themeColor)
                    else
                      _NotMeasuring(
                        state: state,
                        onRetry: notifier.startScanning,
                        onTurnOnLocation: notifier.openLocationSettings,
                      ),
                    gap,
                    _Panel(
                      child: RfHistoryChart(
                        history: state.history,
                        color: themeColor,
                        isMeasuring: isMeasuring,
                      ),
                    ),
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
                ),
              ),
            ),
          ),
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

/// Source line: the phone's radio, LIVE / STOPPED, Pahara node badge.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state, required this.color});

  final RfDetectorState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final live = state.isMeasuring;
    final badge = state.isHardwareNodeNearby
        ? 'rf_badge_node'
        : live
        ? 'rf_badge_live'
        : 'rf_badge_stopped';
    final badgeColor = state.isHardwareNodeNearby
        ? colors.tertiary
        : live
        ? RfColors.quiet
        : colors.outline;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.settings_input_antenna_rounded,
            color: color,
            size: 20.w,
          ),
        ),
        SizedBox(width: AppDimens.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rf_phone_radio'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                state.hardwareNodeName ??
                    (live
                        ? 'rf_scanning_hint'.tr()
                        : 'rf_readings_paused'.tr()),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        // Long badges ("PAHARA NODE NEARBY") shrink instead of
        // pushing the row off a small screen.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8.w, color: badgeColor),
                  SizedBox(width: 4.w),
                  Text(
                    badge.tr(),
                    style: textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Devices transmitting · signals per second · peak.
class _Stats extends StatelessWidget {
  const _Stats({required this.state});

  final RfDetectorState state;

  @override
  Widget build(BuildContext context) {
    final live = state.isMeasuring;
    final peak = live && state.peakDbm != null
        ? state.peakDbm!.round().toString()
        : '--';
    return Row(
      children: [
        _Stat(
          icon: Icons.devices_other_rounded,
          value: live ? '${state.activeTransmitters}' : '--',
          label: 'rf_stat_devices'.tr(),
        ),
        SizedBox(width: 8.w),
        _Stat(
          icon: Icons.graphic_eq_rounded,
          value: live ? '${state.packetsPerSecond}' : '--',
          label: 'rf_stat_rate'.tr(),
        ),
        SizedBox(width: 8.w),
        _Stat(
          icon: Icons.trending_up_rounded,
          value: 'rf_peak'.tr(args: {'value': peak}),
          label: 'rf_stat_peak'.tr(),
        ),
      ],
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
              maxLines: 1,
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
  const _Guidance({required this.level, required this.color});

  final RfThreatLevel level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final icon = switch (level) {
      RfThreatLevel.quiet => Icons.check_circle_outline_rounded,
      RfThreatLevel.moderate => Icons.directions_walk_rounded,
      RfThreatLevel.strong => Icons.warning_amber_rounded,
    };
    return Container(
      key: const Key('rf_guidance'),
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

/// The one place that says the meter isn't measuring, why, and the fix.
class _NotMeasuring extends StatelessWidget {
  const _NotMeasuring({
    required this.state,
    required this.onRetry,
    required this.onTurnOnLocation,
  });

  final RfDetectorState state;
  final VoidCallback onRetry;
  final VoidCallback onTurnOnLocation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reason = state.isStarting
        ? 'rf_starting'.tr()
        : (state.errorKey ?? 'rf_reason_stopped').tr();
    final hint = state.isStarting
        ? null
        : state.isLocationOff
        ? 'rf_location_off_hint'.tr()
        : state.isBluetoothOff
        ? 'rf_bluetooth_off_hint'.tr()
        : 'rf_not_measuring_hint'.tr();
    return Container(
      key: const Key('rf_not_measuring'),
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                state.isStarting
                    ? Icons.hourglass_top_rounded
                    : Icons.portable_wifi_off_rounded,
                color: colors.onSurfaceVariant,
              ),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Text(
                  'rf_not_measuring_title'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(reason, style: textTheme.bodyMedium),
          if (hint != null) ...[
            SizedBox(height: 4.h),
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (!state.isStarting) ...[
            SizedBox(height: AppDimens.spacingSmall),
            if (state.isLocationOff)
              FilledButton.icon(
                onPressed: onTurnOnLocation,
                icon: const Icon(Icons.location_on_rounded),
                label: Text('rf_turn_on_location'.tr()),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('rf_retry'.tr()),
              ),
          ],
        ],
      ),
    );
  }
}
