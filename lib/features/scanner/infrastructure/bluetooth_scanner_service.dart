import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/models/device_model.dart';
import '../domain/services/bluetooth_scanner_service.dart';

/// Handles Bluetooth scanning for the platform and adapts it to the domain contract.
class FlutterBluetoothScannerService implements BluetoothScannerService {
  const FlutterBluetoothScannerService();

  @override
  Stream<List<DeviceModel>> scanDevices() async* {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await for (final scanResult in FlutterBluePlus.scanResults) {
        final devices = scanResult
            .map(
              (result) => DeviceModel(
                deviceId: result.device.remoteId.toString(),
                name: result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : 'Unknown Device',
                status: result.advertisementData.connectable
                    ? 'active'
                    : 'inactive',
                lastSeen: DateTime.now(),
                signalStrength: result.rssi,
              ),
            )
            .toList();
        yield devices;
      }
    } catch (error) {
      yield* Stream.error(StateError('Bluetooth scanning failed: $error'));
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<void> stopScanning() => FlutterBluePlus.stopScan();

  @override
  Stream<BluetoothAvailability> bluetoothAvailability() {
    return FlutterBluePlus.adapterState.map((state) {
      switch (state) {
        case BluetoothAdapterState.on:
          return BluetoothAvailability.enabled;
        case BluetoothAdapterState.off:
          return BluetoothAvailability.disabled;
        default:
          return BluetoothAvailability.unavailable;
      }
    });
  }

  @override
  Future<void> requestPermission() async {
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth is not available on this device.');
    }

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      throw StateError('Bluetooth is switched off.');
    }
  }
}
