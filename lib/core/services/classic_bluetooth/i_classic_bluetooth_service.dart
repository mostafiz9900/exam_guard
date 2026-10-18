import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/classic_bluetooth/classic_bluetooth_service_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// One classic (BR/EDR) Bluetooth device found by an inquiry scan.
class ClassicBtRecord {
  const ClassicBtRecord({
    required this.address,
    required this.name,
    required this.rssi,
    required this.majorDeviceClass,
    required this.deviceClass,
    required this.timestamp,
  });

  /// Upper-case MAC address.
  final String address;

  /// Device name, or empty when the device didn't report one.
  final String name;

  /// Signal strength at discovery time (dBm), if reported.
  final int? rssi;

  /// Bluetooth major device class (e.g. 0x0400 audio/video, 0x0200 phone,
  /// 0x0700 wearable), if reported.
  final int? majorDeviceClass;

  /// Full Bluetooth device class (major + minor bits), if reported.
  final int? deviceClass;
  final DateTime timestamp;
}

/// Classic Bluetooth discovery (Android only). Many cheap "spy" earpieces
/// and neckloops use classic Bluetooth and are invisible to BLE scans.
///
/// Discovery is shared like the BLE scan: each feature calls [start] with an
/// owner key and [stop] when done; inquiry cycles repeat while any owner is
/// active.
abstract interface class IClassicBluetoothService {
  /// False on platforms without classic discovery (iOS).
  bool get isSupported;

  /// Devices found while any owner is active (a device repeats each cycle).
  Stream<ClassicBtRecord> get discoveries;

  Future<void> start(String owner);

  Future<void> stop(String owner);

  /// Pauses inquiry cycles while [key] holds a pause (a running inquiry is
  /// cancelled). Finder screens use this: an inquiry starves BLE scanning
  /// for ~12 s, which makes live signal tracking drop out.
  Future<void> suspend(String key);

  /// Releases [key]'s pause; cycles resume when no pause is held.
  Future<void> resume(String key);

  Future<void> dispose();
}

final classicBluetoothServiceProvider = Provider<IClassicBluetoothService>((
  ref,
) {
  final service = ClassicBluetoothServiceImpl(ref.read(appLoggerProvider));
  ref.onDispose(service.dispose);
  return service;
});
