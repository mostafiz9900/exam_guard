import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/core/widgets/app_loader.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/detail_row.dart';
import 'package:exam_guard/features/scanner/view/widgets/multi_target_radar_chart_widget.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/device_shimmer_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/tactical_sweep_painter.dart';
import 'package:exam_guard/features/scanner/view/widgets/radar_ring.dart';

enum DeviceFilter {
  all,
  connected,
  strongSignal,
  audioDevices,
  wifiHotspots,
  wearables,
  covertEsp,
  smartphones;

  /// Translation key of the filter chip label.
  String get labelKey => switch (this) {
    DeviceFilter.all => 'scan_filter_all',
    DeviceFilter.connected => 'scan_filter_connected',
    DeviceFilter.strongSignal => 'scan_filter_strong',
    DeviceFilter.audioDevices => 'scan_filter_audio',
    DeviceFilter.wifiHotspots => 'scan_filter_hotspots',
    DeviceFilter.wearables => 'scan_filter_wearables',
    DeviceFilter.covertEsp => 'scan_filter_esp32',
    DeviceFilter.smartphones => 'scan_filter_smartphones',
  };
}

class WirelessScannerScreen extends HookConsumerWidget {
  const WirelessScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scannerState = ref.watch(scannerViewModelProvider);
    final scannerNotifier = ref.read(scannerViewModelProvider.notifier);

    // Active category filter & view mode hooks
    final activeFilter = useState(DeviceFilter.all);
    final isRadarMapView = useState(
      false,
    ); // false = List View (Default), true = Radar Map View

    // Auto-start scanning on screen mount
    useEffect(() {
      Future.microtask(() {
        if (!scannerState.isScanning) {
          scannerNotifier.toggleScanning(true);
        }
      });
      return null;
    }, const []);

    // Radar animations
    final pulseController = useAnimationController(
      duration: const Duration(seconds: 2),
    );
    final sweepController = useAnimationController(
      duration: const Duration(seconds: 3),
    );

    // Drive radar animation when scanning
    useEffect(() {
      if (scannerState.isScanning) {
        pulseController.repeat();
        sweepController.repeat();
      } else {
        pulseController.stop();
        pulseController.reset();
        sweepController.stop();
        sweepController.reset();
      }
      return null;
    }, [scannerState.isScanning]);

    // Error feedback snackbar
    ref.listen(scannerViewModelProvider, (previous, next) {
      final error = next.errorMessage;
      if (error != null &&
          (error != previous?.errorMessage ||
              next.errorArgs != previous?.errorArgs)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.tr(args: next.errorArgs)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // Filter devices based on Room Boundary Mode & User Filters
    final baseDevices = scannerState.activeDevices;
    final filteredDevices = baseDevices.where((device) {
      switch (activeFilter.value) {
        case DeviceFilter.all:
          return true;
        case DeviceFilter.connected:
          return device.isConnected;
        case DeviceFilter.strongSignal:
          return device.rssi > -65;
        case DeviceFilter.audioDevices:
          return device.deviceType.contains('Audio') ||
              device.name.toLowerCase().contains('headset') ||
              device.name.toLowerCase().contains('airpod') ||
              device.name.toLowerCase().contains('buds') ||
              device.name.toLowerCase().contains('tws');
        case DeviceFilter.wifiHotspots:
          return device.deviceType.contains('Hotspot') ||
              device.name.toLowerCase().contains('hotspot') ||
              device.name.toLowerCase().contains('tether') ||
              device.name.toLowerCase().contains('direct-');
        case DeviceFilter.wearables:
          return device.deviceType.contains('Wearable') ||
              device.name.toLowerCase().contains('watch') ||
              device.name.toLowerCase().contains('band');
        case DeviceFilter.covertEsp:
          return device.deviceType.contains('ESP32') ||
              device.manufacturer.contains('Espressif') ||
              device.name.toLowerCase().contains('esp32');
        case DeviceFilter.smartphones:
          return device.deviceType.contains('Smartphone') ||
              device.name.toLowerCase().contains('iphone') ||
              device.name.toLowerCase().contains('galaxy') ||
              device.name.toLowerCase().contains('pixel') ||
              device.name.toLowerCase().contains('phone');
      }
    }).toList();

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
            // Play / Stop scanning button
            IconButton(
              icon: Icon(
                scannerState.isScanning
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded,
                size: 28.w,
              ),
              tooltip: scannerState.isScanning
                  ? 'stop_scanning'.tr()
                  : 'start_scanning'.tr(),
              onPressed: () {
                scannerNotifier.toggleScanning();
              },
            ),
            const AppSettingsMenu(),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Top Section: Compact Tactical Radar Visualizer Header
                  Container(
                    height: 125.h,
                    margin: EdgeInsets.fromLTRB(
                      AppDimens.spacingLarge,
                      AppDimens.spacingSmall,
                      AppDimens.spacingLarge,
                      AppDimens.spacingSmall,
                    ),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                      ),
                      child: AnimatedBuilder(
                        animation: pulseController,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Compact concentric radar rings
                              if (scannerState.isScanning) ...[
                                RadarRing(
                                  scale: 0.35 + (pulseController.value * 0.65),
                                  opacity: (1.0 - pulseController.value).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                ),
                                RadarRing(
                                  scale:
                                      0.2 +
                                      (((pulseController.value + 0.5) % 1.0) *
                                          0.7),
                                  opacity: (0.7 - (pulseController.value * 0.5))
                                      .clamp(0.0, 1.0),
                                ),
                                AppLoader.ripple(
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 85.w,
                                ),
                              ] else ...[
                                const RadarRing(scale: 0.5, opacity: 0.2),
                                const RadarRing(scale: 0.25, opacity: 0.35),
                              ],

                              // Compact rotating sweep beam
                              if (scannerState.isScanning)
                                AnimatedBuilder(
                                  animation: sweepController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      size: Size(110.w, 110.w),
                                      painter: TacticalSweepPainter(
                                        angle:
                                            sweepController.value * 2 * math.pi,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    );
                                  },
                                ),

                              // Center Bluetooth Icon
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.bluetooth_searching_rounded,
                                  size: 24.w,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),

                              // Status Badge Positioned at Bottom
                              Positioned(
                                bottom: 6.h,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scannerState.isScanning
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.12)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Text(
                                    scannerState.isScanning
                                        ? 'scan_live_devices'.tr(
                                            args: {
                                              'count':
                                                  '${scannerState.activeDevices.length}',
                                            },
                                          )
                                        : 'scan_paused'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                          color: scannerState.isScanning
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : Colors.grey.shade700,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Room Boundary Mode Control Banner (ON/OFF Toggle & Room Size Selector)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingLarge,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: scannerState.isRoomBoundaryMode
                            ? Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                        border: Border.all(
                          color: scannerState.isRoomBoundaryMode
                              ? Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.25)
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            scannerState.isRoomBoundaryMode
                                ? Icons.meeting_room_rounded
                                : Icons.public_rounded,
                            size: 20.w,
                            color: scannerState.isRoomBoundaryMode
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade700,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      scannerState.isRoomBoundaryMode
                                          ? 'scan_boundary_on'.tr()
                                          : 'scan_boundary_off'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                scannerState.isRoomBoundaryMode
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                : Colors.grey.shade800,
                                          ),
                                    ),
                                    if (scannerState.isRoomBoundaryMode) ...[
                                      SizedBox(width: 4.w),
                                      PopupMenuButton<RoomSizePreset>(
                                        initialValue:
                                            scannerState.roomSizePreset,
                                        tooltip: 'scan_boundary_size_tooltip'
                                            .tr(),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.tune_rounded,
                                          size: 15.w,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        onSelected: (preset) {
                                          scannerNotifier.setRoomSizePreset(
                                            preset,
                                          );
                                        },
                                        itemBuilder: (context) {
                                          return RoomSizePreset.values.map((
                                            preset,
                                          ) {
                                            return PopupMenuItem<
                                              RoomSizePreset
                                            >(
                                              value: preset,
                                              child: Text(
                                                preset.labelKey.tr(),
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  scannerState.isRoomBoundaryMode
                                      ? 'scan_boundary_limit'.tr(
                                          args: {
                                            'room': scannerState
                                                .roomSizePreset
                                                .labelKey
                                                .tr(),
                                          },
                                        )
                                      : 'scan_boundary_unrestricted'.tr(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 10.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: scannerState.isRoomBoundaryMode,
                            activeTrackColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            onChanged: (val) {
                              scannerNotifier.toggleRoomBoundaryMode(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Middle Section: Device Category Filter Chips Bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingLarge,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: DeviceFilter.values.map((filter) {
                          final isSelected = activeFilter.value == filter;
                          return Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: FilterChip(
                              label: Text(filter.labelKey.tr()),
                              selected: isSelected,
                              onSelected: (_) => activeFilter.value = filter,
                              showCheckmark: false,
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.18),
                              labelStyle: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Header for Discovered Devices Count & View Mode Toggle (List 📋 vs Radar Map 📡)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingLarge,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 16.w,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'scan_discovered_count'.tr(
                            args: {'count': '${filteredDevices.length}'},
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                        ),
                        const Spacer(),

                        // View Mode Toggle Segmented Control (List 📋 vs Radar Map 📡)
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => isRadarMapView.value = false,
                                borderRadius: BorderRadius.circular(14.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isRadarMapView.value
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.list_alt_rounded,
                                        size: 14.w,
                                        color: !isRadarMapView.value
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'scan_view_list'.tr(),
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: !isRadarMapView.value
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => isRadarMapView.value = true,
                                borderRadius: BorderRadius.circular(14.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isRadarMapView.value
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.radar_rounded,
                                        size: 14.w,
                                        color: isRadarMapView.value
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'scan_view_radar'.tr(),
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: isRadarMapView.value
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // Bottom Section: Maximized Device List OR Interactive Multi-Target Radar Map
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        scannerNotifier.clearResults();
                        await scannerNotifier.toggleScanning(true);
                      },
                      child: isRadarMapView.value
                          // 📡 Multi-Target Interactive Radar Map View
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: AppDimens.spacingLarge,
                              ),
                              child: Column(
                                children: [
                                  Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusLarge,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        AppDimens.spacingMedium,
                                      ),
                                      child: MultiTargetRadarChartWidget(
                                        devices: filteredDevices,
                                        sweepController: sweepController,
                                        onDeviceTap: (device) {
                                          context.pushTo(
                                            AppRoute.radar,
                                            extra: device,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'scan_radar_map_hint'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                  SizedBox(height: 16.h),
                                ],
                              ),
                            )
                          // 📋 Default Professional Device List View
                          : scannerState.isScanning &&
                                scannerState.devices.isEmpty
                          // Ultra-Professional Shimmer Loading Skeleton
                          ? ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: AppDimens.spacingLarge,
                                vertical: 4.h,
                              ),
                              itemCount: 5,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: AppDimens.spacingSmall),
                              itemBuilder: (_, _) => const DeviceShimmerCard(),
                            )
                          : filteredDevices.isEmpty
                          // Empty State
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 220.h,
                                alignment: Alignment.center,
                                child: scannerState.isBluetoothOff
                                    ? Card(
                                        elevation: 3,
                                        color: Colors.red.shade50,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusLarge,
                                          ),
                                          side: const BorderSide(
                                            color: Colors.red,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            AppDimens.spacingLarge,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons
                                                    .bluetooth_disabled_rounded,
                                                size: 48.w,
                                                color: Colors.red,
                                              ),
                                              SizedBox(height: 8.h),
                                              Text(
                                                'scan_bt_off_title'.tr(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15.sp,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                'scan_bt_off_message'.tr(),
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: Colors.red.shade700,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(height: 12.h),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => ref
                                                    .read(
                                                      scannerViewModelProvider
                                                          .notifier,
                                                    )
                                                    .enableBluetooth(),
                                                icon: Icon(
                                                  Icons
                                                      .bluetooth_searching_rounded,
                                                  size: 16.w,
                                                ),
                                                label: Text(
                                                  'scan_bt_turn_on'.tr(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Card(
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusMedium,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            AppDimens.spacingLarge,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .bluetooth_disabled_rounded,
                                                  size: 40.w,
                                                  color: Colors.grey.shade400,
                                                ),
                                                SizedBox(height: 10.h),
                                                Text(
                                                  scannerState.isScanning
                                                      ? 'scan_empty_scanning'
                                                            .tr()
                                                      : (scannerState
                                                                .isRoomBoundaryMode
                                                            ? 'scan_empty_in_boundary'.tr(
                                                                args: {
                                                                  'room': scannerState
                                                                      .roomSizePreset
                                                                      .labelKey
                                                                      .tr(),
                                                                },
                                                              )
                                                            : 'scan_empty_no_match'
                                                                  .tr()),
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Colors.grey,
                                                      ),
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  scannerState
                                                          .isRoomBoundaryMode
                                                      ? 'scan_empty_boundary_hint'
                                                            .tr()
                                                      : 'scan_empty_refresh_hint'
                                                            .tr(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            )
                          // Discovered Device List
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                AppDimens.spacingLarge,
                                0,
                                AppDimens.spacingLarge,
                                AppDimens.spacingLarge,
                              ),
                              itemCount: filteredDevices.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: AppDimens.spacingSmall),
                              itemBuilder: (context, index) {
                                final device = filteredDevices[index];
                                return ProfessionalDeviceCard(
                                  key: ValueKey(device.id),
                                  device: device,
                                  onTrackTap: () {
                                    context.pushTo(
                                      AppRoute.radar,
                                      extra: device,
                                    );
                                  },
                                  onLogTap: () {
                                    context.pushTo(
                                      AppRoute.actionNew,
                                      extra: device,
                                    );
                                  },
                                  onInfoTap: () {
                                    _showDeviceDetailsModal(
                                      context,
                                      device,
                                      onConnect: () => scannerNotifier
                                          .probeDeviceConnection(device.id),
                                    );
                                  },
                                  onDisconnectTap: () => scannerNotifier
                                      .disconnectDevice(device.id),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Displays detailed BLE payload & vendor inspector modal
  void _showDeviceDetailsModal(
    BuildContext context,
    ScannedDeviceModel device, {
    required VoidCallback onConnect,
  }) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.memory_rounded,
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
                          device.displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          deviceTypeLabel(device.deviceType),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              DetailRow(
                label: 'scan_detail_manufacturer'.tr(),
                value: manufacturerLabel(device.manufacturer),
              ),
              DetailRow(
                label: 'scan_detail_mac'.tr(),
                value: device.id,
                monospace: true,
              ),
              DetailRow(
                label: 'scan_detail_rssi'.tr(),
                value: '${device.rssi} dBm',
              ),
              DetailRow(
                label: 'scan_detail_tx_power'.tr(),
                value: device.txPower != null
                    ? '${device.txPower} dBm'
                    : 'scan_detail_not_advertised'.tr(),
              ),
              DetailRow(
                label: 'scan_detail_connection'.tr(),
                value: device.isConnectable
                    ? 'scan_detail_connectable'.tr()
                    : 'scan_detail_broadcast_only'.tr(),
              ),
              if (device.serviceUuids.isNotEmpty)
                DetailRow(
                  label: 'scan_detail_services'.tr(),
                  value: device.serviceUuids.join(', '),
                ),
              if (device.isConnectable &&
                  !device.isConnected &&
                  !device.isConnecting) ...[
                SizedBox(height: AppDimens.spacingMedium),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onConnect();
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: Text('scan_connect_read_info'.tr()),
                  ),
                ),
              ],
              SizedBox(height: AppDimens.spacingMedium),
            ],
          ),
        );
      },
    );
  }
}
