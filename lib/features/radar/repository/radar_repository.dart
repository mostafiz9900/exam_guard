import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';

/// One received signal from the tracked device.
class RadarSignal {
  const RadarSignal({required this.rssi, required this.timestamp});

  final int rssi;
  final DateTime timestamp;
}

/// Live signal strength of a single BLE device.
class RadarRepository {
  RadarRepository(this._bluetooth);

  static const String _scanOwner = 'tracking_radar';

  final IBluetoothService _bluetooth;

  Future<void> startTracking() => _bluetooth.startScan(_scanOwner);

  Future<void> stopTracking() => _bluetooth.stopScan(_scanOwner);

  /// Every advertisement from [deviceId] while tracking.
  Stream<RadarSignal> watchDevice(String deviceId) => _bluetooth.scanRecords
      .where((r) => r.id == deviceId)
      .map((r) => RadarSignal(rssi: r.rssi, timestamp: r.timestamp));
}

final radarRepositoryProvider = Provider<RadarRepository>(
  (ref) => RadarRepository(ref.watch(bluetoothServiceProvider)),
);
