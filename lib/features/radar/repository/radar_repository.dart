import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';

/// One received signal from the tracked device.
class RadarSignal {
  const RadarSignal({required this.rssi, required this.timestamp});

  final int rssi;
  final DateTime timestamp;
}

/// Live signal strength of a single BLE device.
class RadarRepository {
  RadarRepository(this._bluetooth, this._permissions);

  static const String _scanOwner = 'tracking_radar';

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;

  Future<void> startTracking() => _bluetooth.startScan(_scanOwner);

  Future<void> stopTracking() => _bluetooth.stopScan(_scanOwner);

  /// What currently stops the scan from receiving anything (e.g. Location
  /// off), or null when it works. Current value first, then every change.
  /// The scan resumes by itself once the problem clears.
  Stream<BleScanError?> scanProblem() => _bluetooth.scanProblem;

  /// Opens the system Location settings.
  Future<bool> openLocationSettings() => _permissions.openLocationSettings();

  /// Every advertisement from [deviceId] while tracking.
  Stream<RadarSignal> watchDevice(String deviceId) => _bluetooth.scanRecords
      .where((r) => r.id == deviceId)
      .map((r) => RadarSignal(rssi: r.rssi, timestamp: r.timestamp));
}

final radarRepositoryProvider = Provider<RadarRepository>(
  (ref) => RadarRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
