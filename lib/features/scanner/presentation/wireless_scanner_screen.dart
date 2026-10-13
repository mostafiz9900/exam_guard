import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../application/scanner_provider.dart';
import '../domain/scanned_device_model.dart';

enum DeviceFilter {
  all,
  connected,
  strongSignal,
  audioDevices,
  wifiHotspots,
  wearables,
  covertEsp,
  smartphones;

  String get label {
    switch (this) {
      case DeviceFilter.all:
        return 'All Targets';
      case DeviceFilter.connected:
        return 'Connected 🔗';
      case DeviceFilter.strongSignal:
        return 'Strong (> -65 dBm)';
      case DeviceFilter.audioDevices:
        return 'Earbuds & AirPods';
      case DeviceFilter.wifiHotspots:
        return 'Wi-Fi Hotspots & Tethering';
      case DeviceFilter.wearables:
        return 'Smartwatches';
      case DeviceFilter.covertEsp:
        return 'Covert ESP32';
      case DeviceFilter.smartphones:
        return 'Smartphones';
    }
  }
}

class WirelessScannerScreen extends HookConsumerWidget {
  const WirelessScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scannerState = ref.watch(scannerProvider);
    final scannerNotifier = ref.read(scannerProvider.notifier);

    // Active category filter & view mode hooks
    final activeFilter = useState(DeviceFilter.all);
    final isRadarMapView = useState(false); // false = List View (Default), true = Radar Map View

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
    ref.listen(scannerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
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
              device.name.toLowerCase().contains('ap') ||
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
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
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
            tooltip: scannerState.isScanning ? 'Stop Scan' : 'Start Scan',
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
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                    ),
                    child: AnimatedBuilder(
                      animation: pulseController,
                      builder: (context, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Compact concentric radar rings
                            if (scannerState.isScanning) ...[
                              _RadarRing(
                                scale: 0.35 + (pulseController.value * 0.65),
                                opacity:
                                    (1.0 - pulseController.value).clamp(0.0, 1.0),
                              ),
                              _RadarRing(
                                scale: 0.2 +
                                    (((pulseController.value + 0.5) % 1.0) *
                                        0.7),
                                opacity: (0.7 - (pulseController.value * 0.5))
                                    .clamp(0.0, 1.0),
                              ),
                              SpinKitRipple(
                                color: Theme.of(context).colorScheme.primary,
                                size: 85.w,
                              ),
                            ] else ...[
                              const _RadarRing(scale: 0.5, opacity: 0.2),
                              const _RadarRing(scale: 0.25, opacity: 0.35),
                            ],

                            // Compact rotating sweep beam
                            if (scannerState.isScanning)
                              AnimatedBuilder(
                                animation: sweepController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: Size(110.w, 110.w),
                                    painter: _TacticalSweepPainter(
                                      angle:
                                          sweepController.value * 2 * math.pi,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                },
                              ),

                            // Center Bluetooth Icon
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
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
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Text(
                                  scannerState.isScanning
                                      ? 'LIVE • ${scannerState.activeDevices.length} DEVICES'
                                      : 'PAUSED',
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
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                      border: Border.all(
                        color: scannerState.isRoomBoundaryMode
                            ? Theme.of(context)
                                .colorScheme
                                .primary
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
                                        ? 'EXAM ROOM BOUNDARY: ON'
                                        : 'UNRESTRICTED SCAN: OFF',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scannerState.isRoomBoundaryMode
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey.shade800,
                                        ),
                                  ),
                                  if (scannerState.isRoomBoundaryMode) ...[
                                    SizedBox(width: 4.w),
                                    PopupMenuButton<RoomSizePreset>(
                                      initialValue: scannerState.roomSizePreset,
                                      tooltip: 'Change Room Boundary Size',
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
                                        scannerNotifier
                                            .setRoomSizePreset(preset);
                                      },
                                      itemBuilder: (context) {
                                        return RoomSizePreset.values
                                            .map((preset) {
                                          return PopupMenuItem<RoomSizePreset>(
                                            value: preset,
                                            child: Text(
                                              preset.label,
                                              style: TextStyle(fontSize: 12.sp),
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
                                    ? 'Limits scan to ${scannerState.roomSizePreset.label}'
                                    : 'Scans max distance (Includes outside hallway)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
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
                  padding:
                      EdgeInsets.symmetric(horizontal: AppDimens.spacingLarge),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DeviceFilter.values.map((filter) {
                        final isSelected = activeFilter.value == filter;
                        return Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: FilterChip(
                            label: Text(filter.label),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: AppDimens.spacingLarge),
                  child: Row(
                    children: [
                      Icon(
                        Icons.radar_rounded,
                        size: 16.w,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Discovered Targets (${filteredDevices.length})',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                      'List',
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
                                      'Radar Map',
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
                                    child: _MultiTargetRadarChartWidget(
                                      devices: filteredDevices,
                                      sweepController: sweepController,
                                      onDeviceTap: (device) {
                                        context.push('/radar', extra: device);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Tap any target dot on the radar map to open live 1-on-1 Tracking Radar',
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
                        : scannerState.isScanning && scannerState.devices.isEmpty
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
                                itemBuilder: (_, _) =>
                                    const _DeviceShimmerCard(),
                              )
                            : filteredDevices.isEmpty
                                // Empty State
                                ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Container(
                                      height: 220.h,
                                      alignment: Alignment.center,
                                      child: scannerState.isBluetoothOff
                                          ? Card(
                                              elevation: 3,
                                              color: Colors.red.shade50,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                    AppDimens.radiusLarge),
                                                side: const BorderSide(
                                                    color: Colors.red, width: 1.5),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                    AppDimens.spacingLarge),
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
                                                      'Bluetooth Must Be Turned ON!',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15.sp,
                                                        color: Colors.red.shade900,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      'ExamGuard requires active Bluetooth & Location services to scan hall frequencies and detect earpieces, smartwatches, and mobile hotspots.',
                                                      style: TextStyle(
                                                        fontSize: 11.sp,
                                                        color: Colors.red.shade700,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                    SizedBox(height: 12.h),
                                                    ElevatedButton.icon(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                      onPressed: () => ref
                                                          .read(scannerProvider
                                                              .notifier)
                                                          .enableBluetooth(),
                                                      icon: Icon(
                                                          Icons
                                                              .bluetooth_searching_rounded,
                                                          size: 16.w),
                                                      label: const Text(
                                                          'Turn ON Bluetooth Now'),
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
                                                    AppDimens.spacingLarge),
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
                                                            ? 'Scanning BLE frequencies...'
                                                            : (scannerState
                                                                    .isRoomBoundaryMode
                                                                ? 'No targets detected inside Room Boundary (${scannerState.roomSizePreset.label}).'
                                                                : 'No matching devices found.'),
                                                        textAlign: TextAlign.center,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                color: Colors.grey),
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Text(
                                                        scannerState
                                                                .isRoomBoundaryMode
                                                            ? 'Turn OFF Room Boundary Mode to include outside hallway.'
                                                            : 'Tap Play button or pull down to refresh.',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                                color: Colors
                                                                    .grey.shade600),
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
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      AppDimens.spacingLarge,
                                      0,
                                      AppDimens.spacingLarge,
                                      AppDimens.spacingLarge,
                                    ),
                                    itemCount: filteredDevices.length,
                                    separatorBuilder: (_, _) => SizedBox(
                                      height: AppDimens.spacingSmall,
                                    ),
                                    itemBuilder: (context, index) {
                                      final device = filteredDevices[index];
                                      return _ProfessionalDeviceCard(
                                        device: device,
                                        onTrackTap: () {
                                          context.push('/radar', extra: device);
                                        },
                                        onLogTap: () {
                                          context.push('/action/new',
                                              extra: device);
                                        },
                                        onInfoTap: () {
                                          _showDeviceDetailsModal(
                                            context,
                                            device,
                                            onConnect: () => scannerNotifier
                                                .probeDeviceConnection(
                                                    device.id),
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          device.deviceType,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _DetailRow(
                  label: 'Hardware Manufacturer', value: device.manufacturer),
              _DetailRow(label: 'MAC Address (ID)', value: device.id),
              _DetailRow(label: 'RSSI Signal', value: '${device.rssi} dBm'),
              _DetailRow(
                label: 'Tx Power Level',
                value: device.txPower != null
                    ? '${device.txPower} dBm'
                    : 'Not Advertised',
              ),
              _DetailRow(
                label: 'Connection Capability',
                value: device.isConnectable
                    ? 'Connectable Peripheral'
                    : 'Broadcast Beacon',
              ),
              if (device.serviceUuids.isNotEmpty)
                _DetailRow(
                  label: 'Service UUIDs',
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
                    label: const Text('Connect & Read Device Info'),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: label.contains('MAC') ? 'monospace' : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Multi-Target Radar Chart Widget with Gesture Detector
class _MultiTargetRadarChartWidget extends StatelessWidget {
  const _MultiTargetRadarChartWidget({
    required this.devices,
    required this.sweepController,
    required this.onDeviceTap,
  });

  final List<ScannedDeviceModel> devices;
  final AnimationController sweepController;
  final void Function(ScannedDeviceModel device) onDeviceTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = math.min(constraints.maxWidth, 280.w);

        return Column(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final localPos = details.localPosition;
                final center = Offset(chartSize / 2, chartSize / 2);
                final maxRadius = chartSize / 2;

                for (int i = 0; i < devices.length; i++) {
                  final device = devices[i];
                  final blipRatio =
                      ((device.rssi + 100).clamp(0, 70) / 70.0).clamp(0.1, 0.9);
                  final blipDistance = maxRadius * (1.0 - blipRatio);
                  final blipAngle = -math.pi / 2 +
                      (i * 2 * math.pi / math.max(1, devices.length));

                  final blipX = center.dx + blipDistance * math.cos(blipAngle);
                  final blipY = center.dy + blipDistance * math.sin(blipAngle);
                  final blipPos = Offset(blipX, blipY);

                  if ((localPos - blipPos).distance <= 24.w) {
                    onDeviceTap(device);
                    return;
                  }
                }
              },
              child: AnimatedBuilder(
                animation: sweepController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(chartSize, chartSize),
                    painter: _MultiTargetRadarPainter(
                      sweepAngle: sweepController.value * 2 * math.pi,
                      devices: devices,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            // Quick Target Selection Chips Row for 1-Tap Tracking
            Text(
              'Tap Target below or click Red Dot on Radar Map:',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10.sp,
                    color: Colors.grey,
                  ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: devices.map((d) {
                final color = d.rssi > -60
                    ? const Color(0xFFEF4444)
                    : (d.rssi > -75
                        ? const Color(0xFFF97316)
                        : const Color(0xFF10B981));
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: color,
                    radius: 4.r,
                  ),
                  label: Text(
                    '${d.displayName} (${d.rssi}dBm)',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => onDeviceTap(d),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// Custom Painter for 360° Multi-Target Radar Chart plotting ALL discovered devices
class _MultiTargetRadarPainter extends CustomPainter {
  _MultiTargetRadarPainter({
    required this.sweepAngle,
    required this.devices,
  });

  final double sweepAngle;
  final List<ScannedDeviceModel> devices;

  Color _getThreatColor(int rssi) {
    if (rssi > -60) return const Color(0xFFEF4444); // Red Critical
    if (rssi > -75) return const Color(0xFFF97316); // Orange High
    if (rssi > -88) return const Color(0xFFF59E0B); // Yellow Medium
    return const Color(0xFF10B981); // Green Low
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final gridPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar distance rings
    final radii = [
      maxRadius * 0.25,
      maxRadius * 0.50,
      maxRadius * 0.75,
      maxRadius,
    ];
    final distanceLabels = ['1.5m', '3.0m', '4.5m', '6.0m+'];

    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];
      canvas.drawCircle(center, r, ringPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: distanceLabels[i],
          style: TextStyle(
            color: Colors.teal.shade700,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 4, center.dy - r - 10));
    }

    // Draw crosshair axes
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Draw 360° rotating radar sweep beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();

    // Center Inspector Phone Icon Dot
    canvas.drawCircle(center, 5, Paint()..color = AppColors.primary);

    // Plot ALL discovered devices as interactive target dots on radar map
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      final color = _getThreatColor(device.rssi);

      final blipRatio =
          ((device.rssi + 100).clamp(0, 70) / 70.0).clamp(0.1, 0.9);
      final blipDistance = maxRadius * (1.0 - blipRatio);

      // Distribute device dots evenly around 360° radar plane
      final blipAngle =
          -math.pi / 2 + (i * 2 * math.pi / math.max(1, devices.length));
      final blipX = center.dx + blipDistance * math.cos(blipAngle);
      final blipY = center.dy + blipDistance * math.sin(blipAngle);
      final blipPos = Offset(blipX, blipY);

      // Draw connecting line to center
      canvas.drawLine(
        center,
        blipPos,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1.0,
      );

      // Outer glowing pulse circle
      canvas.drawCircle(
        blipPos,
        12.0,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );

      // Inner target dot
      canvas.drawCircle(
        blipPos,
        6.0,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Device name compact label tag
      final namePainter = TextPainter(
        text: TextSpan(
          text: device.displayName.substring(
            0,
            math.min(7, device.displayName.length),
          ),
          style: TextStyle(
            color: color,
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            backgroundColor: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(blipX + 6, blipY - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _MultiTargetRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.devices != devices;
  }
}

/// Ultra-Professional Device List Card with Signal Bars, Vendor Badge & Quick Actions
class _ProfessionalDeviceCard extends StatelessWidget {
  const _ProfessionalDeviceCard({
    required this.device,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
    required this.onDisconnectTap,
  });

  final ScannedDeviceModel device;
  final VoidCallback onTrackTap;
  final VoidCallback onLogTap;
  final VoidCallback onInfoTap;
  final VoidCallback onDisconnectTap;

  Color _getSignalColor(int rssi) {
    if (rssi > -60) {
      return const Color(0xFF10B981); // Green (Strong)
    } else if (rssi > -75) {
      return const Color(0xFFF59E0B); // Yellow (Good)
    } else if (rssi > -88) {
      return const Color(0xFFF97316); // Orange (Medium)
    } else {
      return const Color(0xFFEF4444); // Red (Weak)
    }
  }

  IconData _getDeviceCategoryIcon(String type) {
    if (type.contains('Hotspot') || type.contains('AP')) {
      return Icons.wifi_tethering_rounded;
    } else if (type.contains('Audio')) {
      return Icons.headset_mic_rounded;
    } else if (type.contains('Wearable')) {
      return Icons.watch_rounded;
    } else if (type.contains('Smartphone')) {
      return Icons.smartphone_rounded;
    } else if (type.contains('ESP32')) {
      return Icons.developer_board_rounded;
    } else {
      return Icons.bluetooth_searching_rounded;
    }
  }

  String _getShortCategoryLabel(String type) {
    if (type.contains('ESP32')) return 'Covert ESP32';
    if (type.contains('Audio')) return 'Smart Earpiece';
    if (type.contains('Hotspot') || type.contains('AP')) return 'Wi-Fi Hotspot';
    if (type.contains('Wearable')) return 'Smartwatch';
    if (type.contains('Smartphone')) return 'Smartphone';
    return 'BLE Target';
  }

  int _getSignalBars(int rssi) {
    if (rssi > -60) return 4;
    if (rssi > -75) return 3;
    if (rssi > -88) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor(device.rssi);
    final icon = _getDeviceCategoryIcon(device.deviceType);
    final bars = _getSignalBars(device.rssi);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: signalColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onInfoTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMedium),
          child: Column(
            children: [
              Row(
                children: [
                  // Category Icon Avatar
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: signalColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: signalColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: signalColor,
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Device Details & Manufacturer Tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        SizedBox(height: 3.h),
                        Wrap(
                          spacing: 4.w,
                          runSpacing: 4.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 130.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 5.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: signalColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5.r),
                                  border: Border.all(
                                    color: signalColor.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 10.w, color: signalColor),
                                    SizedBox(width: 3.w),
                                    Flexible(
                                      child: Text(
                                        _getShortCategoryLabel(device.deviceType),
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.bold,
                                          color: signalColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 110.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 5.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  device.manufacturer,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MAC: ${device.id}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.access_time_rounded,
                              size: 10.w,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              DateFormat('hh:mm:ss a').format(device.lastSeen),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Visual Signal Strength & 4-Bar Meter
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SignalBarsWidget(
                            bars: bars,
                            color: signalColor,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${device.rssi} dBm',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: signalColor,
                                  fontSize: 12.sp,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        bars == 4
                            ? 'CRITICAL'
                            : (bars == 3 ? 'STRONG' : 'DISTANT'),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                  color: signalColor,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              if (device.isConnected) ...[
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green.shade300, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link_rounded,
                              size: 14.w, color: Colors.green.shade800),
                          SizedBox(width: 4.w),
                          Text(
                            'CONNECTED',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const Spacer(),
                          if (device.batteryLevel != null) ...[
                            Icon(Icons.battery_std_rounded,
                                size: 12.w, color: Colors.green.shade800),
                            Text(
                              ' ${device.batteryLevel}%',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                          ),
                          onPressed: onDisconnectTap,
                          icon: Icon(Icons.link_off_rounded, size: 13.w),
                          label: Text('Disconnect',
                              style: TextStyle(fontSize: 10.sp)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 14),

              // Bottom Action Toolbar: Track Radar, Log Violation & Info
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTrackTap,
                      icon: Icon(
                        Icons.radar_rounded,
                        size: 15.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'Track Radar',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onLogTap,
                      icon: Icon(
                        Icons.report_problem_rounded,
                        size: 15.w,
                      ),
                      label: Text(
                        'Log Violation',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, size: 18.w),
                    tooltip: 'Inspect BLE Payload',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onInfoTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic 4-Bar Signal Indicator Widget
class _SignalBarsWidget extends StatelessWidget {
  const _SignalBarsWidget({
    required this.bars,
    required this.color,
  });

  final int bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final isActive = index < bars;
        final height = 5.h + (index * 2.5.h);
        return Container(
          width: 3.w,
          height: height,
          margin: EdgeInsets.only(right: 2.w),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2.r),
          ),
        );
      }),
    );
  }
}

/// Shimmer Skeleton Loading Card
class _DeviceShimmerCard extends StatelessWidget {
  const _DeviceShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 80.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130.w,
                    height: 12.h,
                    color: Colors.white,
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: 80.w,
                    height: 9.h,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Container(
              width: 50.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactical Sweep Rotating Radar Painter
class _TacticalSweepPainter extends CustomPainter {
  _TacticalSweepPainter({
    required this.angle,
    required this.color,
  });

  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TacticalSweepPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

class _RadarRing extends StatelessWidget {
  const _RadarRing({required this.scale, required this.opacity});
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 110.w,
        height: 110.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(
              alpha: opacity.clamp(0.0, 1.0),
            ),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}


