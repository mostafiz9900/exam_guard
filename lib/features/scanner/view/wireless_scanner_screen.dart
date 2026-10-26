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
import 'package:exam_guard/features/scanner/view/widgets/new_device_alerts_banner.dart';
import 'package:exam_guard/features/scanner/view/widgets/new_devices_pill.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/room_boundary_panel.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_empty_state.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_list_header.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_status_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/walk_selection_bar.dart';
import 'package:exam_guard/features/scanner/view/widgets/wifi_problem_banner.dart';
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
    final scroll = useScrollController();

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
    final newBelow = _useNewDevicesBelow(
      scroll,
      allIds: [for (final g in state.groups) g.id],
      visibleIds: {for (final g in groups) g.id},
      enabled: !isRadarMap.value,
    );
    final signalCount = groups.fold<int>(0, (n, g) => n + g.members.length);
    final emptyReason = state.emptyReason(filter.value);
    final gutter = AppDimens.spacingMedium;

    // The radar needs a live BLE signal; classic/Wi-Fi open their details.
    void track(ScannedDeviceModel d) => d.isBle
        ? context.pushTo(AppRoute.radar, extra: d)
        : inspectDevice(context, ref, d);
    void seatSweep(ScannedDeviceModel d) =>
        context.pushTo(AppRoute.seatSweep, extra: d);
    void select(ScannedDeviceModel d) => state.isSelecting
        ? notifier.toggleSelected(d.id)
        : notifier.startSelection(d.id);
    void walkSelected() {
      final targets = state.selectedDevices;
      if (targets.isEmpty) return;
      notifier.cancelSelection();
      context.pushTo(AppRoute.walkFinder, extra: targets);
    }

    void walkStrongest() {
      final targets = notifier.strongestUntrustedTargets();
      if (targets.isNotEmpty) {
        context.pushTo(AppRoute.walkFinder, extra: targets);
      }
    }

    void log(ScannedDeviceModel d) =>
        context.pushTo(AppRoute.actionNew, extra: d);
    void inspect(ScannedDeviceModel d) => inspectDevice(context, ref, d);
    final unseenAlerts = [
      for (final a in state.alerts)
        if (!a.acknowledged) a,
    ];

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
            onOpenSettings: notifier.needsAppSettings
                ? notifier.openAppSettings
                : null,
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
                devices: [
                  for (final g in groups)
                    if (g.primary.isBle) g.primary,
                ],
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
                band: state.bandOf(group.primary),
                isTrusted: state.isGroupTrusted(group),
                hasNewAlert: state.hasUnacknowledgedAlert(group),
                isStale: state.isGroupStale(group),
                isToggling: group.members.any(
                  (m) => state.togglingIds.contains(m.id),
                ),
                secondsSinceSeen: state.secondsSinceSeen(group.primary),
                isSelecting: state.isSelecting,
                isSelected: state.isGroupSelected(group),
                canSeatSweep: state.canSeatSweep(group.primary),
                onSeatSweepTap: seatSweep,
                onSelectTap: select,
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
        if (state.isSelecting) {
          notifier.cancelSelection();
        } else if (context.canPopBack) {
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
              icon: const Icon(Icons.directions_walk_rounded),
              tooltip: 'scan_walk_strongest'.tr(),
              onPressed: walkStrongest,
            ),
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
        bottomNavigationBar: state.isSelecting
            ? WalkSelectionBar(
                count: state.selectedDevices.length,
                max: ScannerState.maxWalkTargets,
                onCancel: notifier.cancelSelection,
                onWalk: walkSelected,
              )
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  notifier.clearResults();
                  await notifier.toggleScanning(true);
                },
                child: CustomScrollView(
                  controller: scroll,
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
                        transportCounts: ScannerState.countByTransport(groups),
                        isRadarMap: isRadarMap.value,
                        onRadarMapChanged: (v) => isRadarMap.value = v,
                        sortMode: state.sortMode,
                        onSortModeChanged: notifier.setSortMode,
                      ),
                    ),
                    if (state.isLocationOff)
                      padded(
                        LocationOffBanner(
                          onTurnOn: notifier.openLocationSettings,
                        ),
                      ),
                    if (WifiProblemBanner.shows(state.wifiProblem))
                      padded(WifiProblemBanner(problem: state.wifiProblem!)),
                    if (unseenAlerts.isNotEmpty)
                      padded(
                        NewDeviceAlertsBanner(
                          alerts: unseenAlerts,
                          onMarkAllSeen: notifier.acknowledgeAll,
                        ),
                      ),
                    ...content,
                  ],
                ),
              ),
              if (newBelow.value > 0 && !isRadarMap.value)
                Positioned(
                  bottom: 12.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: NewDevicesPill(
                      count: newBelow.value,
                      onTap: () {
                        newBelow.value = 0;
                        if (!scroll.hasClients) return;
                        scroll.animateTo(
                          scroll.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Counts devices that appeared below the part of the list in view (new
/// devices are appended at the bottom). Reset when the user scrolls to the
/// bottom. Devices already known when the screen opened don't count.
ValueNotifier<int> _useNewDevicesBelow(
  ScrollController scroll, {
  required List<String> allIds,
  required Set<String> visibleIds,
  required bool enabled,
}) {
  final count = useState(0);
  final known = useRef<Set<String>?>(null);
  final alive = useRef(true);
  useEffect(
    () =>
        () => alive.value = false,
    const [],
  );
  final key = allIds.join('|');

  useEffect(() {
    final seen = known.value;
    if (seen == null) {
      known.value = {...allIds};
      return null;
    }
    final added = [
      for (final id in allIds)
        if (seen.add(id) && visibleIds.contains(id)) id,
    ];
    if (added.isEmpty || !enabled) return null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!alive.value || !scroll.hasClients) return;
      if (scroll.position.extentAfter > 24) count.value += added.length;
    });
    return null;
  }, [key, enabled]);

  useEffect(() {
    void onScroll() {
      if (count.value > 0 &&
          scroll.hasClients &&
          scroll.position.extentAfter < 24) {
        count.value = 0;
      }
    }

    scroll.addListener(onScroll);
    return () => scroll.removeListener(onScroll);
  }, [scroll]);

  return count;
}

/// Details sheet of [device] with Trust/Untrust (and Seat sweep when the
/// exam has a seat layout); acknowledges its alert.
void inspectDevice(
  BuildContext context,
  WidgetRef ref,
  ScannedDeviceModel device,
) {
  final notifier = ref.read(scannerViewModelProvider.notifier);
  final state = ref.read(scannerViewModelProvider);
  final isTrusted = state.isTrusted(device.id);
  notifier.acknowledgeAlert(device.id);
  showDeviceDetailsSheet(
    context,
    device,
    isTrusted: isTrusted,
    onSeatSweep: state.canSeatSweep(device)
        ? () => context.pushTo(AppRoute.seatSweep, extra: device)
        : null,
    history: notifier.historyOf(device.id),
    onConnect: () => notifier.probeDeviceConnection(device.id),
    onToggleTrust: () => isTrusted
        ? notifier.untrustDevice(device.id)
        : notifier.trustDevice(device.id),
  );
}
