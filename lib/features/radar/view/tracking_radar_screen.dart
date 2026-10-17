import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/radar/view_model/tracking_radar_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/view/widgets/direction_step_item.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_painter.dart';

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
        return const Color(0xFF3B82F6); // Blue (No clear change)
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

  /// Localized version of [TrackingRadarState.formatDistance].
  static String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters >= 10) return 'radar_distance_far'.tr(args: {'meters': '10'});
    return 'radar_distance_approx'.tr(
      args: {'meters': meters.toStringAsFixed(1)},
    );
  }

  static String _trimMeters(double meters) => meters == meters.roundToDouble()
      ? meters.toStringAsFixed(0)
      : meters.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarState = ref.watch(trackingRadarViewModelProvider);
    final radarNotifier = ref.read(trackingRadarViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryText = colorScheme.onSurfaceVariant;
    final neutralColor = colorScheme.outline;

    // Initialize target device when screen mounts or targetDevice changes
    useEffect(() {
      if (targetDevice != null) {
        Future.microtask(() => radarNotifier.setTargetDevice(targetDevice!));
      }
      return null;
    }, [targetDevice]);

    // Radar beam rotation animation controller
    final beamController = useAnimationController(
      duration: const Duration(seconds: 3),
    );
    useEffect(() {
      beamController.repeat();
      return null;
    }, [beamController]);

    final activeDevice = radarState.device ?? targetDevice;
    final isLive = radarState.hasLiveSignal;
    final threatColor = isLive
        ? _getThreatColor(radarState.threatLevel)
        : neutralColor;
    final trendColor = isLive ? _getTrendColor(radarState.trend) : neutralColor;
    final trendIcon = isLive
        ? _getTrendIcon(radarState.trend)
        : (radarState.isLocationOff
              ? Icons.location_off_rounded
              : radarState.errorKey != null
              ? Icons.bluetooth_disabled_rounded
              : Icons.bluetooth_searching_rounded);

    final String trendTitle;
    final String trendText;
    if (radarState.isLocationOff) {
      trendTitle = 'radar_location_off_title'.tr();
      trendText = 'radar_location_off_text'.tr();
    } else if (radarState.errorKey != null) {
      trendTitle = 'radar_scan_failed_title'.tr();
      trendText = radarState.errorKey!.tr();
    } else if (radarState.isSignalLost) {
      trendTitle = 'radar_signal_lost_title'.tr();
      trendText = 'radar_signal_lost_text'.tr();
    } else if (radarState.isAcquiring) {
      trendTitle = 'radar_acquiring_title'.tr();
      trendText = 'radar_acquiring_text'.tr();
    } else {
      trendTitle = radarState.trend.labelKey.tr();
      trendText = radarState.trend.instructionKey.tr();
    }

    final String threatTitle;
    final String threatText;
    if (isLive) {
      threatTitle = radarState.threatLevel.labelKey.tr();
      threatText = radarState.threatLevel.descriptionKey.tr();
    } else if (radarState.isLocationOff) {
      threatTitle = 'radar_not_measuring'.tr();
      threatText = 'radar_location_off_distance_text'.tr();
    } else if (radarState.errorKey != null) {
      threatTitle = 'radar_not_measuring'.tr();
      threatText = 'radar_not_measuring_text'.tr();
    } else if (radarState.isSignalLost) {
      threatTitle = 'radar_no_live_signal'.tr();
      threatText = 'radar_no_live_signal_text'.tr();
    } else {
      threatTitle = 'radar_acquiring'.tr();
      threatText = 'radar_acquiring_distance_text'.tr();
    }

    final distanceText = _formatDistance(radarState.distanceMeters);
    final ringLabels = [
      for (final m in RadarPainter.ringMeters)
        (m == RadarPainter.maxMeters
                ? 'radar_ring_meters_max'
                : 'radar_ring_meters')
            .tr(args: {'meters': _trimMeters(m)}),
    ];

    Future<void> logIncident(ScannedDeviceModel device) async {
      radarNotifier.setAlertsSuspended(true);
      await context.pushTo(
        AppRoute.actionNew,
        extra: ActionEntryArgs(
          device: device,
          category: 'Bluetooth Device',
          notes: radarNotifier.incidentNotes(),
        ),
      );
      if (context.mounted) radarNotifier.setAlertsSuspended(false);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('tracking_radar'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, size: 24.w),
            tooltip: 'radar_guide_title'.tr(),
            onPressed: () => _showDirectionGuideModal(context),
          ),
          IconButton(
            icon: Icon(
              radarState.isAudioAlertEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            tooltip: 'radar_audio_tooltip'.tr(),
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
                        color: neutralColor,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'radar_no_target_title'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'radar_no_target_text'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: secondaryText),
                      ),
                      SizedBox(height: 24.h),
                      PrimaryButton(
                        label: 'open_scanner'.tr(),
                        onPressed: () => context.pushTo(AppRoute.scanner),
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
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                            border: Border.all(
                              color: trendColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(trendIcon, color: trendColor, size: 24.w),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trendTitle,
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
                                      trendText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 10.sp,
                                            color: secondaryText,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (radarState.isLocationOff) ...[
                                SizedBox(width: 8.w),
                                FilledButton.tonalIcon(
                                  onPressed: radarNotifier.openLocationSettings,
                                  icon: Icon(
                                    Icons.location_on_rounded,
                                    size: 16.w,
                                  ),
                                  label: Text('radar_turn_on_location'.tr()),
                                ),
                              ] else if (radarState.errorKey != null) ...[
                                SizedBox(width: 8.w),
                                OutlinedButton(
                                  onPressed: radarNotifier.retry,
                                  child: Text('radar_retry'.tr()),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingMedium),

                        // Threat Status Banner
                        Container(
                          padding: EdgeInsets.all(AppDimens.spacingMedium),
                          decoration: BoxDecoration(
                            color: threatColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
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
                                  isLive
                                      ? Icons.warning_amber_rounded
                                      : Icons.help_outline_rounded,
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
                                      threatTitle,
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
                                      threatText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Distance-only radar display
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusLarge,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(AppDimens.spacingMedium),
                              child: AnimatedBuilder(
                                animation: beamController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: RadarPainter(
                                      sweepAngle:
                                          beamController.value * 2 * math.pi,
                                      distanceMeters: isLive
                                          ? radarState.distanceMeters
                                          : null,
                                      color: threatColor,
                                      badgeLabel: isLive
                                          ? '${radarState.threatLevel.labelKey.tr()} · '
                                                '$distanceText'
                                          : null,
                                      ringLabels: ringLabels,
                                      note: 'radar_distance_only'.tr(),
                                      textDirection: Directionality.of(context),
                                      gridColor: colorScheme.primary,
                                      labelColor: secondaryText,
                                      badgeTextColor: Colors.white,
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
                                            isLive
                                                ? distanceText
                                                : (radarState.isAcquiring
                                                      ? 'radar_acquiring_center'
                                                            .tr()
                                                      : '--'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: threatColor,
                                                ),
                                          ),
                                          Text(
                                            radarState.smoothedRssi == null
                                                ? '-- dBm'
                                                : '${radarState.smoothedRssi!.round()} dBm',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  fontFamily: 'monospace',
                                                  fontSize: 11.sp,
                                                  color: secondaryText,
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
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingMedium),
                            child: Column(
                              children: [
                                _InfoRow(
                                  label: 'radar_target_name'.tr(),
                                  value: activeDevice.displayName,
                                  valueStyle: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Divider(height: 16),
                                _InfoRow(
                                  label: 'device_id'.tr(),
                                  value: activeDevice.id,
                                  valueStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Action Buttons
                        PrimaryButton(
                          label: 'log_incident'.tr(),
                          onPressed: () => logIncident(activeDevice),
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
                          color: Theme.of(context).colorScheme.primary
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
                              'radar_guide_title'.tr(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'radar_guide_subtitle'.tr(),
                              style: Theme.of(context).textTheme.bodySmall
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
                  DirectionStepItem(
                    stepNumber: '1',
                    title: 'radar_guide_step1_title'.tr(),
                    description: 'radar_guide_step1_text'.tr(),
                    icon: Icons.directions_walk_rounded,
                  ),
                  DirectionStepItem(
                    stepNumber: '2',
                    title: 'radar_guide_step2_title'.tr(),
                    description: 'radar_guide_step2_text'.tr(
                      args: {
                        'closer': ProximityTrend.approaching.labelKey.tr(),
                        'away': ProximityTrend.receding.labelKey.tr(),
                        'steady': ProximityTrend.stationary.labelKey.tr(),
                      },
                    ),
                    icon: Icons.alt_route_rounded,
                  ),
                  DirectionStepItem(
                    stepNumber: '3',
                    title: 'radar_guide_step3_title'.tr(),
                    description: 'radar_guide_step3_text'.tr(
                      args: {
                        'critical': ThreatLevel.critical.labelKey.tr(),
                        'meters': _trimMeters(ThreatLevel.criticalWithin),
                      },
                    ),
                    icon: Icons.pin_drop_rounded,
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  PrimaryButton(
                    label: 'radar_guide_done'.tr(),
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

/// Label on the left, value on the right; long values (e.g. 36-char iOS
/// device ids) are ellipsized instead of overflowing.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              value,
              style: valueStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
