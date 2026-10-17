import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/widgets/device_details_sheet.dart';
import 'package:exam_guard/features/scanner/view/widgets/device_shimmer_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/location_off_banner.dart';
import 'package:exam_guard/features/scanner/view/widgets/multi_target_radar_chart_widget.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/room_boundary_panel.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_empty_state.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_list_header.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_status_card.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

ScannerStatusKind _statusOf(ScannerState s) {
  if (s.isLocationOff) return ScannerStatusKind.locationOff;
  if (s.isBluetoothOff) return ScannerStatusKind.bluetoothOff;
  if (s.errorMessage != null) return ScannerStatusKind.failed;
  if (s.isScanning) return ScannerStatusKind.live;
  return ScannerStatusKind.paused;
}

class WirelessScannerScreen extends HookConsumerWidget {
  const WirelessScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerViewModelProvider);
    final notifier = ref.read(scannerViewModelProvider.notifier);

    final filter = useState(DeviceFilter.all);
    final isRadarMap = useState(false);

    // Auto-start scanning on screen mount.
    useEffect(() {
      Future.microtask(() {
        if (!state.isScanning) notifier.toggleScanning(true);
      });
      return null;
    }, const []);

    final status = _statusOf(state);
    final isLive = status == ScannerStatusKind.live;
    final pulse = useAnimationController(duration: const Duration(seconds: 2));
    final sweep = useAnimationController(duration: const Duration(seconds: 3));
    useEffect(() {
      if (isLive) {
        pulse.repeat();
        sweep.repeat();
      } else {
        pulse
          ..stop()
          ..reset();
        sweep
          ..stop()
          ..reset();
      }
      return null;
    }, [isLive]);

    // One-off notices and new blocking errors as snackbars.
    ref.listen(scannerViewModelProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final scheme = Theme.of(context).colorScheme;
      final notice = next.noticeKey;
      if (notice != null && next.noticeId != previous?.noticeId) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(notice.tr(args: next.noticeArgs)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      final error = next.errorMessage;
      if (error != null &&
          (error != previous?.errorMessage ||
              next.errorArgs != previous?.errorArgs)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error.tr(args: next.errorArgs),
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final groups = state.visibleGroups(filter.value);
    final signalCount = groups.fold<int>(0, (n, g) => n + g.members.length);
    final emptyReason = state.emptyReason(filter.value);
    final gutter = AppDimens.spacingMedium;

    void track(ScannedDeviceModel d) =>
        context.pushTo(AppRoute.radar, extra: d);
    void log(ScannedDeviceModel d) =>
        context.pushTo(AppRoute.actionNew, extra: d);
    void inspect(ScannedDeviceModel d) => showDeviceDetailsSheet(
      context,
      d,
      onConnect: () => notifier.probeDeviceConnection(d.id),
    );

    Widget padded(Widget child) => SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, 10.h, gutter, 0),
      sliver: SliverToBoxAdapter(child: child),
    );

    final List<Widget> content;
    if (emptyReason == ScannerEmptyReason.waiting) {
      content = [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 10.h, gutter, gutter),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => SizedBox(height: 8.h),
            itemBuilder: (_, _) => const DeviceShimmerCard(),
          ),
        ),
      ];
    } else if (emptyReason != null) {
      content = [
        padded(
          ScannerEmptyState(
            reason: emptyReason,
            totalDevices: emptyReason == ScannerEmptyReason.outsideBoundary
                ? state.groups.length
                : state.activeGroups.length,
            roomLabel: state.roomSizePreset.labelKey.tr(),
            errorText: state.errorMessage?.tr(args: state.errorArgs),
            onEnableBluetooth: notifier.enableBluetooth,
            onRetry: () => notifier.toggleScanning(true),
            onShowAll: () => filter.value = DeviceFilter.all,
            onDisableBoundary: () => notifier.toggleRoomBoundaryMode(false),
          ),
        ),
      ];
    } else if (isRadarMap.value) {
      content = [
        padded(
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: MultiTargetRadarChartWidget(
                devices: [for (final g in groups) g.primary],
                sweepController: sweep,
                onDeviceTap: track,
              ),
            ),
          ),
        ),
        padded(
          Text(
            'scan_radar_map_hint'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: gutter)),
      ];
    } else {
      content = [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 10.h, gutter, gutter),
          sliver: SliverList.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ProfessionalDeviceCard(
                key: ValueKey(group.id),
                group: group,
                onTrackTap: track,
                onLogTap: log,
                onInfoTap: inspect,
                onDisconnectTap: (d) => notifier.disconnectDevice(d.id),
              );
            },
          ),
        ),
      ];
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
          title: Text('wireless_scanner'.tr()),
          actions: [
            IconButton(
              icon: Icon(
                state.isScanning
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded,
                size: 28.w,
              ),
              tooltip: state.isScanning
                  ? 'stop_scanning'.tr()
                  : 'start_scanning'.tr(),
              onPressed: notifier.toggleScanning,
            ),
            const AppSettingsMenu(),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              notifier.clearResults();
              await notifier.toggleScanning(true);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 8.h, gutter, 0),
                  sliver: SliverToBoxAdapter(
                    child: ScannerStatusCard(
                      kind: status,
                      deviceCount: state.activeGroups.length,
                      signalCount: state.activeDevices.length,
                      pulse: pulse,
                      sweep: sweep,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 8.h, gutter, 4.h),
                  sliver: SliverToBoxAdapter(
                    child: RoomBoundaryPanel(
                      enabled: state.isRoomBoundaryMode,
                      preset: state.roomSizePreset,
                      onToggle: notifier.toggleRoomBoundaryMode,
                      onPresetSelected: notifier.setRoomSizePreset,
                    ),
                  ),
                ),
                PinnedHeaderSliver(
                  child: ScannerListHeader(
                    filter: filter.value,
                    onFilterChanged: (f) => filter.value = f,
                    deviceCount: groups.length,
                    signalCount: signalCount,
                    isRadarMap: isRadarMap.value,
                    onRadarMapChanged: (v) => isRadarMap.value = v,
                  ),
                ),
                if (state.isLocationOff)
                  padded(
                    LocationOffBanner(onTurnOn: notifier.openLocationSettings),
                  ),
                ...content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
