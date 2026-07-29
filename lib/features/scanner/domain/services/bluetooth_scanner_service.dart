import '../models/device_model.dart';

/// Platform-agnostic Bluetooth scanner abstraction for ExamGuard.
abstract class BluetoothScannerService {
  Stream<List<DeviceModel>> scanDevices();

  Future<void> stopScanning();

  Stream<BluetoothAvailability> bluetoothAvailability();

  Future<void> requestPermission();
}

enum BluetoothAvailability { unknown, unavailable, disabled, enabled }
