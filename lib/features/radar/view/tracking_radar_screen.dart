import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/model/proximity_meter.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_gauge.dart';
import 'package:exam_guard/features/radar/view/widgets/distance_band_card.dart';
import 'package:exam_guard/features/radar/view/widgets/finder_issue_banner.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_action_bar.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_hero_card.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_how_to_find.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_target_header.dart';
import 'package:exam_guard/features/radar/view_model/tracking_radar_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Hot/cold finder for one device: target header, closeness gauge hero,
/// distance band and a collapsible guide; actions sit in a sticky bar.
class TrackingRadarScreen extends HookConsumerWidget {
  const TrackingRadarScreen({super.key, this.targetDevice});

  final ScannedDeviceModel? targetDevice;

  /// Localized version of [TrackingRadarState.formatDistance].
  static String formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters >= 10) return 'radar_distance_far'.tr(args: {'meters': '10'});
    return 'radar_distance_approx'.tr(
      args: {'meters': meters.toStringAsFixed(1)},
    );
  }

  static GaugeMode modeOf(TrackingRadarState s) {
    if (s.isLocationOff || s.errorKey != null) return GaugeMode.off;
    if (s.isSignalLost) return GaugeMode.lost;
    if (s.hasLiveSignal) return GaugeMode.live;
    return GaugeMode.acquiring;
  }

  static FinderScanIssue? issueOf(TrackingRadarState s) {
    if (s.isLocationOff) return FinderScanIssue.locationOff;
    final key = s.errorKey;
    if (key == null) return null;
    if (key == 'radar_err_scan_throttled') return FinderScanIssue.throttled;
    return FinderScanIssue.failed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarState = ref.watch(trackingRadarViewModelProvider);
    final radarNotifier = ref.read(trackingRadarViewModelProvider.notifier);

    useEffect(() {
      if (targetDevice != null) {
        Future.microtask(() => radarNotifier.setTargetDevice(targetDevice!));
      }
      return null;
    }, [targetDevice]);

    final activeDevice = radarState.device ?? targetDevice;
    final mode = modeOf(radarState);
    _useSecondTicker(mode == GaugeMode.lost);

    final isTrusted = activeDevice == null
        ? false
        : ref.watch(
            scannerViewModelProvider.select(
              (s) => s.isTrusted(activeDevice.id),
            ),
          );

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

    Future<void> openSeatSweep(ScannedDeviceModel device) async {
      radarNotifier.setAlertsSuspended(true);
      await context.pushTo(AppRoute.seatSweep, extra: device);
      if (context.mounted) radarNotifier.setAlertsSuspended(false);
    }

    Future<void> copyId(ScannedDeviceModel device) async {
      await Clipboard.setData(ClipboardData(text: device.address));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('radar_id_copied'.tr())));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('tracking_radar'.tr()),
        actions: [
          IconButton(
            key: const Key('radar_toggle_vibration'),
            isSelected: radarState.isVibrationEnabled,
            icon: const Icon(Icons.mobile_off_rounded),
            selectedIcon: const Icon(Icons.vibration_rounded),
            tooltip: 'radar_vibration_tooltip'.tr(),
            onPressed: radarNotifier.toggleVibration,
          ),
          IconButton(
            key: const Key('radar_toggle_audio'),
            isSelected: radarState.isAudioAlertEnabled,
            icon: const Icon(Icons.volume_off_rounded),
            selectedIcon: const Icon(Icons.volume_up_rounded),
            tooltip: 'radar_audio_tooltip'.tr(),
            onPressed: radarNotifier.toggleAudioAlert,
          ),
          const AppSettingsMenu(),
        ],
      ),
      bottomNavigationBar: activeDevice == null
          ? null
          : RadarActionBar(
              onFindSeat: activeDevice.isBle
                  ? () => openSeatSweep(activeDevice)
                  : null,
              onLogIncident: () => logIncident(activeDevice),
            ),
      body: activeDevice == null
          ? const _NoTarget()
          : LayoutBuilder(
              builder: (context, constraints) => _buildBody(
                context,
                constraints,
                radarState,
                activeDevice,
                mode,
                isTrusted,
                onCopyId: () => copyId(activeDevice),
                onResetPeak: radarNotifier.resetPeak,
                onOpenLocation: radarNotifier.openLocationSettings,
                onRetry: radarNotifier.retry,
              ),
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BoxConstraints constraints,
    TrackingRadarState s,
    ScannedDeviceModel device,
    GaugeMode mode,
    bool isTrusted, {
    required VoidCallback onCopyId,
    required VoidCallback onResetPeak,
    required VoidCallback onOpenLocation,
    required VoidCallback onRetry,
  }) {
    final gap = SizedBox(height: AppDimens.spacingSmall);
    final pad = AppDimens.spacingMedium;
    final isWide =
        constraints.maxWidth >= 640 &&
        constraints.maxWidth > constraints.maxHeight;
    final contentWidth = math.min(constraints.maxWidth, 600.0) - pad * 2;
    final columnWidth = isWide ? (contentWidth - pad) / 2 : contentWidth;
    final diameter = math
        .min(
          columnWidth - pad * 2,
          constraints.maxHeight * (isWide ? 0.62 : 0.4),
        )
        .clamp(150.0, 280.0);

    final smoothed = s.smoothedRssi;
    final closeness = mode == GaugeMode.live
        ? s.closeness
        : (mode == GaugeMode.lost && smoothed != null
              ? ProximityMeter.closenessPercent(smoothed)
              : null);
    final hint = switch (mode) {
      GaugeMode.live => s.trend.instructionKey.tr(),
      GaugeMode.acquiring => 'radar_acquiring_text'.tr(),
      GaugeMode.lost => 'radar_signal_lost_text'.tr(),
      GaugeMode.off => null,
    };

    final issue = issueOf(s);
    final header = RadarTargetHeader(
      device: device,
      mode: mode,
      isTrusted: isTrusted,
      onCopyId: onCopyId,
    );
    final banner = issue == null
        ? null
        : FinderIssueBanner(
            key: const Key('radar_issue_banner'),
            issue: issue,
            onOpenLocation: onOpenLocation,
            onTurnOnBluetooth: onRetry,
            onRetry: onRetry,
          );
    final hero = RadarHeroCard(
      gaugeDiameter: diameter,
      mode: mode,
      closeness: closeness,
      smoothedRssi: smoothed,
      distanceText: formatDistance(s.distanceMeters),
      trend: s.trend,
      peakCloseness: s.peakCloseness,
      peakRssi: s.peakRssi,
      hint: hint,
      lastHeardText: mode == GaugeMode.lost ? _lastHeard(device) : null,
      onResetPeak: onResetPeak,
    );
    final band = DistanceBandCard(
      level: mode == GaugeMode.live ? s.threatLevel : null,
    );
    const guide = RadarHowToFind();

    final Widget content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: hero),
              SizedBox(width: pad),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (banner != null) ...[gap, banner],
                    gap,
                    band,
                    gap,
                    guide,
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (banner != null) ...[gap, banner],
              gap,
              hero,
              gap,
              band,
              gap,
              guide,
            ],
          );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, AppDimens.spacingSmall, pad, pad),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 900 : 600),
          child: content,
        ),
      ),
    );
  }

  /// "Last heard 7 s ago"; null when the time is unknown or very old.
  static String? _lastHeard(ScannedDeviceModel device) {
    final seconds = DateTime.now().difference(device.lastSeen).inSeconds;
    if (seconds > 3600) return null;
    if (seconds <= 1) return 'walk_heard_now'.tr();
    return 'walk_last_heard'.tr(args: {'seconds': '$seconds'});
  }
}

/// Rebuilds the widget once a second while [enabled] (for "s ago" text).
void _useSecondTicker(bool enabled) {
  final tick = useState(0);
  useEffect(() {
    if (!enabled) return null;
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => tick.value++,
    );
    return timer.cancel;
  }, [enabled]);
}

class _NoTarget extends StatelessWidget {
  const _NoTarget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.radar_outlined,
                  size: 56.r,
                  color: colors.primary,
                ),
              ),
              SizedBox(height: AppDimens.spacingMedium),
              Text(
                'radar_no_target_title'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.r),
              Text(
                'radar_no_target_text'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: AppDimens.spacingLarge),
              PrimaryButton(
                label: 'open_scanner'.tr(),
                onPressed: () => context.pushTo(AppRoute.scanner),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
