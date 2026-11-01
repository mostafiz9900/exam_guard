import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/ble_gatt_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// A GATT connection could not be opened or an operation on it failed.
class BleGattException implements Exception {
  const BleGattException(this.message);

  final String message;

  @override
  String toString() => 'BleGattException: $message';
}

/// An open GATT connection to one device. Characteristics are addressed by
/// their service and characteristic UUIDs (any case, 16- or 128-bit).
abstract interface class BleGattLink {
  /// Throws [BleGattException] (same for [write] and [notifications]).
  Future<List<int>> read(String service, String characteristic);

  /// Write with response; long values are split by the platform.
  Future<void> write(String service, String characteristic, List<int> value);

  /// Subscribes and emits every notified value.
  Stream<List<int>> notifications(String service, String characteristic);

  /// Completes when the link drops (or [close] is called).
  Future<void> get done;

  Future<void> close();
}

/// Talks to a device's GATT services. Features use this instead of
/// `flutter_blue_plus`; scanning stays in [IBluetoothService].
abstract interface class IBleGatt {
  /// Connects and discovers services. Throws [BleGattException].
  Future<BleGattLink> open(
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  });
}

final bleGattProvider = Provider<IBleGatt>(
  (ref) => BleGattImpl(ref.read(appLoggerProvider)),
);
