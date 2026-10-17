import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/bluetooth/bluetooth_service_impl.dart';

enum BleAdapterStatus { on, off, unauthorized, unavailable, unknown }

/// One received BLE advertisement.
class BleScanRecord {
  const BleScanRecord({
    required this.id,
    required this.name,
    required this.rssi,
    required this.txPower,
    required this.isConnectable,
    required this.serviceUuids,
    required this.manufacturerData,
    required this.timestamp,
  });

  /// Normalized (trimmed, upper-case) remote id / MAC address.
  final String id;

  /// Advertised name, or platform name, or empty.
  final String name;
  final int rssi;
  final int? txPower;
  final bool isConnectable;
  final List<String> serviceUuids;
  final Map<int, List<int>> manufacturerData;
  final DateTime timestamp;
}

/// A BLE scan could not start or stopped with an error. [message] is
/// ready to show to the user.
enum BleScanError {
  /// Android 11 and older need Location (GPS) switched on to scan.
  locationOff,

  /// Android blocked scanning after too many starts; resumes in ~30 s.
  throttled,
  other,
}

class BleScanException implements Exception {
  const BleScanException(this.message, {this.code = BleScanError.other});

  final String message;

  /// What went wrong, for callers that show their own translated text.
  final BleScanError code;

  @override
  String toString() => message;
}

/// What a GATT connection could read from a device.
class BleConnectionInfo {
  const BleConnectionInfo({this.batteryLevel, this.gattName});

  final int? batteryLevel;
  final String? gattName;
}

/// Bluetooth Low Energy access. Features use this instead of `flutter_blue_plus`.
///
/// The phone has one BLE radio, so the scan is shared: every feature that
/// needs live advertisements calls [startScan] with its own owner key and
/// [stopScan] when done. The radio scans while at least one owner is active.
abstract interface class IBluetoothService {
  Future<bool> isSupported();

  /// Emits the current adapter status, then every change.
  Stream<BleAdapterStatus> adapterStatus();

  /// Asks the OS to turn Bluetooth on (Android only).
  Future<void> turnOn();

  /// Every advertisement received while any owner is scanning.
  /// Scan failures arrive as [BleScanException] errors.
  Stream<BleScanRecord> get scanRecords;

  /// Throws [BleScanException] when the radio cannot start scanning.
  Future<void> startScan(String owner);

  Future<void> stopScan(String owner);

  /// Connects, reads the Battery Service if present, and stays connected.
  Future<BleConnectionInfo> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  Future<void> dispose();
}

final bluetoothServiceProvider = Provider<IBluetoothService>((ref) {
  final service = BluetoothServiceImpl(ref.read(appLoggerProvider));
  ref.onDispose(service.dispose);
  return service;
});
