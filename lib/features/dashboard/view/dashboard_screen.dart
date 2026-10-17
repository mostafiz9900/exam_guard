import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/dashboard/view/widgets/live_stat_badge.dart';
import 'package:exam_guard/features/dashboard/view/widgets/dashboard_module_card.dart';
import 'package:exam_guard/features/dashboard/view/widgets/live_threat_tile.dart';
import 'package:exam_guard/features/dashboard/view/widgets/mini_sweep_painter.dart';
import 'package:exam_guard/features/dashboard/view/widgets/signal_strength.dart';

/// Scanner status as the dashboard shows it.
enum _ScanStatus { live, bluetoothOff, locationOff, failed, stopped }

/// Only blocking problems count: [ScannerState.errorMessage] is a blocking
/// scan problem, while transient notices ([ScannerState.noticeKey]) are not
/// failures and never turn the chip into "SCAN FAILED".
_ScanStatus _scanStatusOf(ScannerState s) {
  if (s.isBluetoothOff) return _ScanStatus.bluetoothOff;
  if (s.isLocationOff) return _ScanStatus.locationOff;
  if (s.errorMessage != null) return _ScanStatus.failed;
  if (s.isScanning) return _ScanStatus.live;
  return _ScanStatus.stopped;
}

/// Amber warning that stays readable on light and dark surfaces.
Color _warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.amber.shade300
    : Colors.orange.shade800;

/// Ordered magnetic levels: critical and above red, elevated orange.
Color _magneticColor(MagneticHazardLevel level) {
  if (level.index >= MagneticHazardLevel.critical.index) return Colors.red;
  if (level == MagneticHazardLevel.elevated) return Colors.orange;
  return Colors.teal;
}

enum _ExitChoice { minimize, endExam }

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rarely-changing state is watched here; live readouts (clock,
    // devices, magnetic field) rebuild in their own small widgets below.
    final session = ref.watch(sessionViewModelProvider);
    // "Scanning" with Location off receives nothing, so only a truly live
    // scan animates the radar and shows the active scanner icon.
    final isScanning = ref.watch(
      scannerViewModelProvider.select(
        (s) => _scanStatusOf(s) == _ScanStatus.live,
      ),
    );

    final room = session?.roomNumber.isNotEmpty == true
        ? 'room'.tr(args: {'room': session!.roomNumber})
        : 'no_active_session'.tr();

    final colors = Theme.of(context).colorScheme;
    final appBarForeground =
        Theme.of(context).appBarTheme.foregroundColor ?? colors.onPrimary;

    // Live radar animation controller
    final sweepController = useAnimationController(
      duration: const Duration(seconds: 3),
    );
    useEffect(() {
      sweepController.repeat();
      return null;
    }, [sweepController]);

    /// Ends the exam and opens its report. Stays on the dashboard with an
    /// error message if the end time could not be saved.
    Future<void> finishExam() async {
      try {
        await ref.read(sessionViewModelProvider.notifier).endCurrentSession();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('end_exam_failed'.tr()),
              backgroundColor: colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (context.mounted) context.goTo(AppRoute.report);
    }

    Future<void> endExam() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('end_exam_title'.tr()),
          content: Text('end_exam_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text('end_exam'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await finishExam();
    }

    Future<_ExitChoice?> showExitDialog() {
      return showDialog<_ExitChoice>(
        context: context,
        builder: (context) {
          final dialogColors = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: dialogColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.exit_to_app_rounded,
                    color: dialogColors.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'exit_dialog_title'.tr(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'exit_dialog_message'.tr(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'exit_dialog_hint'.tr(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: dialogColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 12.h),
                Divider(height: 1, color: dialogColors.outlineVariant),
                SizedBox(height: 4.h),
                // Deliberately low-key: ending is irreversible and opens a
                // second confirmation.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: dialogColors.error,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, _ExitChoice.endExam),
                    icon: Icon(Icons.stop_circle_outlined, size: 18.w),
                    label: Text('dash_exit_end_exam'.tr()),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()),
              ),
              FilledButton.icon(
                autofocus: true,
                onPressed: () => Navigator.pop(context, _ExitChoice.minimize),
                icon: Icon(Icons.minimize_rounded, size: 18.w),
                label: Text('minimize'.tr()),
              ),
            ],
          );
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        switch (await showExitDialog()) {
          case _ExitChoice.minimize:
            SystemNavigator.pop();
          case _ExitChoice.endExam:
            // Second confirmation; one mis-tap must never end the exam.
            await endExam();
          case null:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, color: appBarForeground, size: 22.w),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  'dashboard'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                isScanning
                    ? Icons.cell_wifi_rounded
                    : Icons.portable_wifi_off_rounded,
                color: isScanning
                    ? appBarForeground
                    : appBarForeground.withValues(alpha: 0.6),
              ),
              tooltip: isScanning ? 'scanner_active'.tr() : 'scanner_idle'.tr(),
              onPressed: () => context.pushTo(AppRoute.scanner),
            ),
            if (session != null && session.endTime == null)
              Padding(
                padding: EdgeInsetsDirectional.only(start: 4.w),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    minimumSize: Size(0, 34.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: endExam,
                  icon: Icon(Icons.stop_circle_rounded, size: 18.w),
                  label: Text(
                    'end_exam'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const AppSettingsMenu(),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 650;

              return SingleChildScrollView(
                padding: EdgeInsets.all(AppDimens.spacingLarge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Security Status HUD Hero Card
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLarge,
                            ),
                            side: BorderSide(
                              color: colors.primary.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimens.spacingLarge),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Animated Radar Live Visualizer Icon
                                    AnimatedBuilder(
                                      animation: sweepController,
                                      builder: (context, _) {
                                        return Container(
                                          width: 52.w,
                                          height: 52.w,
                                          decoration: BoxDecoration(
                                            color: colors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colors.primary.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (isScanning)
                                                CustomPaint(
                                                  size: Size(52.w, 52.w),
                                                  painter: MiniSweepPainter(
                                                    angle:
                                                        sweepController.value *
                                                        2 *
                                                        math.pi,
                                                    color: colors.primary,
                                                  ),
                                                ),
                                              Icon(
                                                Icons.radar_rounded,
                                                size: 26.w,
                                                color: colors.primary,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  room,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16.sp,
                                                      ),
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              const Flexible(
                                                child: _ScanStatusChip(),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2.h),
                                          _InstituteClock(
                                            institute:
                                                session
                                                        ?.instituteName
                                                        .isNotEmpty ==
                                                    true
                                                ? session!.instituteName
                                                : '-',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // Real-time Security HUD Counters
                                Row(
                                  children: [
                                    Expanded(
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final count = ref.watch(
                                            scannerViewModelProvider.select(
                                              (s) => s.activeDevices.length,
                                            ),
                                          );
                                          return LiveStatBadge(
                                            icon: Icons.cell_wifi_rounded,
                                            title: 'ble_signals'.tr(),
                                            value: '$count',
                                            color: colors.primary,
                                            onTap: () => context.pushTo(
                                              AppRoute.scanner,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final strong = ref.watch(
                                            scannerViewModelProvider.select(
                                              (s) => s.activeDevices
                                                  .where(
                                                    (d) =>
                                                        SignalStrength.isStrong(
                                                          d.rssi,
                                                        ),
                                                  )
                                                  .length,
                                            ),
                                          );
                                          return LiveStatBadge(
                                            icon: Icons.warning_amber_rounded,
                                            title: 'strong_signals'.tr(),
                                            value: '$strong',
                                            color: strong > 0
                                                ? colors.error
                                                : colors.onSurfaceVariant,
                                            onTap: () => context.pushTo(
                                              AppRoute.scanner,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    const Expanded(child: _MagneticStatBadge()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        Text(
                          'quick_actions'.tr(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                        ),
                        SizedBox(height: AppDimens.spacingSmall),

                        // Responsive Grid Navigation Deck
                        GridView.count(
                          crossAxisCount: isWideScreen ? 3 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: AppDimens.spacingMedium,
                          mainAxisSpacing: AppDimens.spacingMedium,
                          childAspectRatio: 1.15,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final count = ref.watch(
                                  scannerViewModelProvider.select(
                                    (s) => s.activeGroups.length,
                                  ),
                                );
                                return DashboardModuleCard(
                                  icon: Icons.cell_wifi_rounded,
                                  title: 'wireless_scan'.tr(),
                                  subtitle: 'wireless_scan_subtitle'.tr(),
                                  badgeText: 'devices_active'.tr(
                                    args: {'count': '$count'},
                                  ),
                                  color: colors.primary,
                                  onTap: () => context.pushTo(AppRoute.scanner),
                                );
                              },
                            ),
                            DashboardModuleCard(
                              icon: Icons.radar_rounded,
                              title: 'tracking_radar'.tr(),
                              subtitle: 'tracking_radar_subtitle'.tr(),
                              badgeText: 'radar_badge'.tr(),
                              color: Colors.teal,
                              onTap: () => context.pushTo(AppRoute.radar),
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                // Whole μT only, so this rebuilds far less
                                // often than the ~10 Hz sensor stream.
                                final (reading, unavailable) = ref.watch(
                                  magneticViewModelProvider.select(
                                    (s) => (
                                      s.hasReading ? s.magnitude.round() : null,
                                      s.isSensorUnavailable,
                                    ),
                                  ),
                                );
                                return DashboardModuleCard(
                                  icon: unavailable
                                      ? Icons.sensors_off_rounded
                                      : Icons.sensors_rounded,
                                  title: 'magnetic_scan'.tr(),
                                  subtitle: 'magnetic_scan_subtitle'.tr(),
                                  badgeText: unavailable
                                      ? 'dash_mag_not_available'.tr()
                                      : reading == null
                                      ? '—'
                                      : '$reading μT',
                                  color: unavailable
                                      ? colors.onSurfaceVariant
                                      : Colors.indigo,
                                  onTap: () =>
                                      context.pushTo(AppRoute.magnetic),
                                );
                              },
                            ),
                            DashboardModuleCard(
                              icon: Icons.assignment_rounded,
                              title: 'report'.tr(),
                              subtitle: 'report_card_subtitle'.tr(),
                              badgeText: 'incidents_count'.tr(
                                args: {
                                  'count': '${session?.deviceLogs.length ?? 0}',
                                },
                              ),
                              color: colors.tertiary,
                              onTap: () => context.pushTo(AppRoute.report),
                            ),
                            DashboardModuleCard(
                              icon: Icons.settings_input_antenna_rounded,
                              title: 'rf_meter'.tr(),
                              subtitle: 'rf_meter_subtitle'.tr(),
                              badgeText: '2.4 GHz',
                              color: Colors.deepOrange,
                              onTap: () => context.pushTo(AppRoute.rfDetector),
                            ),
                            DashboardModuleCard(
                              icon: Icons.report_problem_rounded,
                              title: 'log_incident'.tr(),
                              subtitle: 'log_incident_subtitle'.tr(),
                              badgeText: 'log_action'.tr(),
                              color: Colors.redAccent,
                              onTap: () => context.pushTo(AppRoute.actionNew),
                            ),
                          ],
                        ),
                        SizedBox(height: AppDimens.spacingLarge),

                        // Section Title: Live Discovered Threats Stream
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'live_feed'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                    ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.pushTo(AppRoute.scanner),
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14.w,
                              ),
                              label: Text(
                                'view_scanner'.tr(),
                                style: TextStyle(fontSize: 11.sp),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppDimens.spacingSmall / 2),
                        const _LiveDeviceFeed(),
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

/// Institute name and a ticking clock. Owns its own timer so the rest of
/// the dashboard doesn't rebuild every second.
class _InstituteClock extends HookWidget {
  const _InstituteClock({required this.institute});

  final String institute;

  @override
  Widget build(BuildContext context) {
    final now = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    return Text(
      '$institute • ${AppDateFormat.clock(now.value)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11.sp,
      ),
    );
  }
}

/// Shows whether BLE monitoring is really running. Tappable when it isn't,
/// so the invigilator can fix it in the scanner.
class _ScanStatusChip extends ConsumerWidget {
  const _ScanStatusChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(scannerViewModelProvider.select(_scanStatusOf));
    final error = Theme.of(context).colorScheme.error;
    final (label, color) = switch (status) {
      _ScanStatus.live => ('status_monitoring_live'.tr(), AppColors.success),
      _ScanStatus.bluetoothOff => ('status_bluetooth_off'.tr(), error),
      _ScanStatus.locationOff => (
        'dash_status_location_off'.tr(),
        _warningColor(context),
      ),
      _ScanStatus.failed => ('status_scan_failed'.tr(), error),
      _ScanStatus.stopped => ('status_scan_stopped'.tr(), error),
    };
    final isLive = status == _ScanStatus.live;

    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (!isLive) ...[
            SizedBox(width: 2.w),
            Icon(
              status == _ScanStatus.locationOff
                  ? Icons.location_on_rounded
                  : Icons.chevron_right_rounded,
              size: 12.w,
              color: color,
            ),
          ],
        ],
      ),
    );

    if (isLive) return chip;
    return Tooltip(
      message: status == _ScanStatus.locationOff
          ? 'dash_turn_on_location'.tr()
          : 'open_scanner'.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: status == _ScanStatus.locationOff
            ? ref.read(scannerViewModelProvider.notifier).openLocationSettings
            : () => context.pushTo(AppRoute.scanner),
        child: chip,
      ),
    );
  }
}

/// Magnetic field readout; rebuilds only when the shown value changes.
class _MagneticStatBadge extends ConsumerWidget {
  const _MagneticStatBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (hasReading, tenths, level, unavailable) = ref.watch(
      magneticViewModelProvider.select(
        (s) => (
          s.hasReading,
          (s.magnitude * 10).round(),
          s.hazardLevel,
          s.isSensorUnavailable,
        ),
      ),
    );
    if (unavailable) {
      // Missing hardware, not a reading: say so in a muted tone.
      return LiveStatBadge(
        icon: Icons.sensors_off_rounded,
        title: 'magnetic_field'.tr(),
        value: 'dash_mag_no_sensor'.tr(),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        onTap: () => context.pushTo(AppRoute.magnetic),
      );
    }
    return LiveStatBadge(
      icon: Icons.sensors_rounded,
      title: 'magnetic_field'.tr(),
      value: hasReading ? '${(tenths / 10).toStringAsFixed(1)} μT' : '—',
      color: hasReading
          ? _magneticColor(level)
          : Theme.of(context).colorScheme.onSurfaceVariant,
      onTap: () => context.pushTo(AppRoute.magnetic),
    );
  }
}

/// Top three nearby devices, or an honest empty state that says why the
/// list is empty.
class _LiveDeviceFeed extends ConsumerWidget {
  const _LiveDeviceFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(scannerViewModelProvider.select(_scanStatusOf));
    final devices = ref.watch(
      scannerViewModelProvider.select((s) => s.activeDevices),
    );
    final colors = Theme.of(context).colorScheme;

    if (devices.isNotEmpty) {
      return Column(
        children: devices.take(3).map((device) {
          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: LiveThreatTile(
              device: device,
              onTrackTap: () => context.pushTo(AppRoute.radar, extra: device),
            ),
          );
        }).toList(),
      );
    }

    final warning = _warningColor(context);
    final (icon, message, isProblem) = switch (status) {
      _ScanStatus.live => (
        Icons.bluetooth_searching_rounded,
        'scanning'.tr(),
        false,
      ),
      _ScanStatus.bluetoothOff => (
        Icons.bluetooth_disabled_rounded,
        'feed_bluetooth_off'.tr(),
        true,
      ),
      _ScanStatus.locationOff => (
        Icons.location_off_rounded,
        'dash_feed_location_off'.tr(),
        true,
      ),
      _ScanStatus.failed => (
        Icons.error_outline_rounded,
        'scan_unavailable'.tr(),
        true,
      ),
      _ScanStatus.stopped => (
        Icons.pause_circle_outline_rounded,
        'feed_scan_stopped'.tr(),
        true,
      ),
    };

    final isLocationOff = status == _ScanStatus.locationOff;
    final iconColor = isLocationOff
        ? warning
        : (isProblem ? colors.error : colors.outline);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 32.w, color: iconColor),
              SizedBox(height: AppDimens.spacingSmall),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (isLocationOff) ...[
                SizedBox(height: AppDimens.spacingSmall),
                FilledButton.icon(
                  onPressed: ref
                      .read(scannerViewModelProvider.notifier)
                      .openLocationSettings,
                  icon: const Icon(Icons.location_on_rounded),
                  label: Text('dash_turn_on_location'.tr()),
                ),
              ] else if (isProblem) ...[
                SizedBox(height: AppDimens.spacingSmall),
                OutlinedButton.icon(
                  onPressed: () => context.pushTo(AppRoute.scanner),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('open_scanner'.tr()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
