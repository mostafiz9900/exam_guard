import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';

/// One received signal from the tracked device.
class RadarSignal {
  const RadarSignal({
    required this.rssi,
    required this.timestamp,
    this.deviceId = '',
  });

  final int rssi;
  final DateTime timestamp;
  final String deviceId;
}

/// Live signal strength of BLE devices for the finder screens (radar, walk
/// finder, seat sweep). Each screen uses its own scan / wake lock owner.
class RadarRepository {
  RadarRepository(this._bluetooth, this._permissions, this._wakelock);

  static const String radarOwner = 'tracking_radar';
  static const String walkFinderOwner = 'walk_finder';
  static const String seatSweepOwner = 'seat_sweep';

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;
  final IWakelockService _wakelock;

  Future<void> startTracking({String owner = radarOwner}) =>
      _bluetooth.startScan(owner);

  Future<void> stopTracking({String owner = radarOwner}) =>
      _bluetooth.stopScan(owner);

  /// What currently stops the scan from receiving anything (e.g. Location
  /// off), or null when it works. Current value first, then every change.
  /// The scan resumes by itself once the problem clears.
  Stream<BleScanError?> scanProblem() => _bluetooth.scanProblem;

  /// Bluetooth adapter state: current value first, then every change.
  Stream<BleAdapterStatus> adapterStatus() => _bluetooth.adapterStatus();

  /// Asks the OS to turn Bluetooth on (Android only).
  Future<void> turnOnBluetooth() => _bluetooth.turnOn();

  /// Opens the system Location settings.
  Future<bool> openLocationSettings() => _permissions.openLocationSettings();

  /// Every advertisement from [deviceId] while tracking.
  Stream<RadarSignal> watchDevice(String deviceId) => watchDevices({deviceId});

  /// Every advertisement from any of [deviceIds] while tracking.
  Stream<RadarSignal> watchDevices(Set<String> deviceIds) => _bluetooth
      .scanRecords
      .where((r) => deviceIds.contains(r.id))
      .map(
        (r) =>
            RadarSignal(rssi: r.rssi, timestamp: r.timestamp, deviceId: r.id),
      );

  /// Keeps the display on while [owner]'s screen is open.
  Future<void> keepScreenOn(String owner) => _wakelock.enable(owner);

  Future<void> releaseScreen(String owner) => _wakelock.disable(owner);
}

final radarRepositoryProvider = Provider<RadarRepository>(
  (ref) => RadarRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
    ref.watch(wakelockServiceProvider),
  ),
);
