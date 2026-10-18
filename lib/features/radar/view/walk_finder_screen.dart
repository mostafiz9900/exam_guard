import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/features/radar/model/walk_finder_models.dart';
import 'package:exam_guard/features/radar/view/widgets/finder_issue_banner.dart';
import 'package:exam_guard/features/radar/view/widgets/proximity_meter_card.dart';
import 'package:exam_guard/features/radar/view_model/walk_finder_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Hands-free finder for the phone-in-pocket walk along the aisles.
class WalkFinderScreen extends HookConsumerWidget {
  const WalkFinderScreen({super.key, required this.devices});

  final List<ScannedDeviceModel> devices;

  static const Color _hot = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walkFinderViewModelProvider);
    final notifier = ref.read(walkFinderViewModelProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    useEffect(() {
      Future.microtask(() => notifier.setTargets(devices));
      return null;
    }, [devices]);

    final veryClose = state.isRunning && state.anyVeryClose;
    final statusColor = !state.isRunning
        ? colors.outline
        : state.issue != null
        ? colors.outline
        : veryClose
        ? _hot
        : colors.primary;
    final statusText = !state.isRunning
        ? 'walk_status_ready'.tr()
        : state.issue != null
        ? 'walk_status_not_scanning'.tr()
        : veryClose
        ? 'walk_very_close'.tr()
        : 'walk_status_searching'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text('walk_title'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              state.isSoundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            tooltip: 'walk_sound_tooltip'.tr(),
            onPressed: notifier.toggleSound,
          ),
          const AppSettingsMenu(),
        ],
      ),
      body: SafeArea(
        child: !devices.any((d) => d.isBle)
            ? _NoTargets(onBack: () => context.popBack())
            : state.targets.isEmpty
            ? const SizedBox.shrink() // targets are set after the first frame
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(AppDimens.spacingMedium),
                      children: [
                        if (state.issue != null) ...[
                          FinderIssueBanner(
                            issue: state.issue!,
                            onOpenLocation: notifier.openLocationSettings,
                            onTurnOnBluetooth: notifier.turnOnBluetooth,
                            onRetry: () async {
                              notifier.stop();
                              await notifier.start();
                            },
                          ),
                          SizedBox(height: AppDimens.spacingSmall),
                        ],
                        // Big status: readable at a glance.
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: EdgeInsets.symmetric(
                            vertical: AppDimens.spacingLarge,
                            horizontal: AppDimens.spacingMedium,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: veryClose ? 0.25 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLarge,
                            ),
                            border: Border.all(color: statusColor, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                veryClose
                                    ? Icons.warning_rounded
                                    : state.isRunning
                                    ? Icons.directions_walk_rounded
                                    : Icons.sensors_rounded,
                                color: statusColor,
                                size: 48.w,
                              ),
                              SizedBox(height: 8.h),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  statusText,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              if (state.isRunning && state.alertCount > 0) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  'walk_alert_count'.tr(
                                    args: {'count': '${state.alertCount}'},
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingMedium),
                        Text(
                          'walk_sensitivity_title'.tr(),
                          style: theme.textTheme.titleSmall,
                        ),
                        SizedBox(height: 6.h),
                        SegmentedButton<WalkSensitivity>(
                          showSelectedIcon: false,
                          segments: [
                            for (final s in WalkSensitivity.values)
                              ButtonSegment(
                                value: s,
                                label: Text(
                                  s.labelKey.tr(
                                    args: {'meters': '${s.approxMeters}'},
                                  ),
                                ),
                              ),
                          ],
                          selected: {state.sensitivity},
                          onSelectionChanged: (s) =>
                              notifier.setSensitivity(s.first),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'walk_sensitivity_hint'.tr(
                            args: {'rssi': '${state.sensitivity.thresholdDbm}'},
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingMedium),
                        for (final t in state.targets)
                          _TargetCard(
                            target: t,
                            now: state.now,
                            isRunning: state.isRunning,
                          ),
                        if (state.skippedNonBle > 0)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(
                              'walk_skipped_devices'.tr(
                                args: {'count': '${state.skippedNonBle}'},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(height: AppDimens.spacingSmall),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined,
                              size: 18.w,
                              color: colors.primary,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'walk_tips'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Big start / stop, reachable with a thumb.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.spacingMedium,
                      0,
                      AppDimens.spacingMedium,
                      AppDimens.spacingMedium,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64.h,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: state.isRunning
                              ? colors.error
                              : colors.primary,
                          foregroundColor: state.isRunning
                              ? colors.onError
                              : colors.onPrimary,
                          textStyle: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: state.isRunning
                            ? notifier.stop
                            : notifier.start,
                        icon: Icon(
                          state.isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 32.w,
                        ),
                        label: Text(
                          state.isRunning
                              ? 'walk_stop'.tr()
                              : 'walk_start'.tr(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    required this.now,
    required this.isRunning,
  });

  final WalkTarget target;
  final DateTime now;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heard = isRunning && target.isHeard(now);
    final closeness = heard ? target.closeness : null;
    final color = target.isVeryClose
        ? WalkFinderScreen._hot
        : closeness == null
        ? colors.outline
        : closenessColor(closeness);

    final last = target.lastHeard;
    final String lastHeardText;
    if (!isRunning) {
      lastHeardText = 'walk_not_running'.tr();
    } else if (last == null) {
      lastHeardText = 'walk_not_heard_yet'.tr();
    } else {
      final seconds = now.difference(last).inSeconds.clamp(0, 9999);
      lastHeardText = seconds <= 1
          ? 'walk_heard_now'.tr()
          : 'walk_last_heard'.tr(args: {'seconds': '$seconds'});
    }

    return Card(
      margin: EdgeInsets.only(bottom: AppDimens.spacingSmall),
      color: target.isVeryClose ? _tint(colors.surface, color) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: target.isVeryClose ? color : colors.outlineVariant,
          width: target.isVeryClose ? 2.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    target.device.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  closeness == null ? '--' : '$closeness%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: LinearProgressIndicator(
                value: (closeness ?? 0) / 100,
                minHeight: 12.h,
                color: color,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lastHeardText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  heard && target.smoothedRssi != null
                      ? '${target.smoothedRssi!.round()} dBm'
                      : '-- dBm',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (target.isVeryClose) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: color, size: 20.w),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'walk_very_close'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _tint(Color surface, Color color) =>
      Color.alphaBlend(color.withValues(alpha: 0.15), surface);
}

class _NoTargets extends StatelessWidget {
  const _NoTargets({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 56.w,
              color: theme.colorScheme.outline,
            ),
            SizedBox(height: 12.h),
            Text(
              'walk_no_targets'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),
            OutlinedButton(onPressed: onBack, child: Text('walk_go_back'.tr())),
          ],
        ),
      ),
    );
  }
}
