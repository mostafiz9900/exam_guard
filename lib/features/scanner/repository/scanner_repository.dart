import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';

/// One advertisement, already classified into a device.
class DeviceSighting {
  const DeviceSighting({required this.device, required this.hasAdvertisedName});

  final ScannedDeviceModel device;

  /// False when [ScannedDeviceModel.name] was inferred from the vendor.
  final bool hasAdvertisedName;
}

/// Live BLE device discovery for the wireless scanner.
class ScannerRepository {
  ScannerRepository(this._bluetooth, this._permissions);

  static const String _scanOwner = 'wireless_scanner';

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;

  Future<bool> isSupported() => _bluetooth.isSupported();

  Stream<bool> bluetoothOn() =>
      _bluetooth.adapterStatus().map((s) => s == BleAdapterStatus.on);

  Future<void> turnOnBluetooth() => _bluetooth.turnOn();

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  Future<void> startScan() => _bluetooth.startScan(_scanOwner);

  Future<void> stopScan() => _bluetooth.stopScan(_scanOwner);

  /// Every advertisement received while scanning, classified.
  Stream<DeviceSighting> sightings() => _bluetooth.scanRecords.map(_classify);

  Future<BleConnectionInfo> connect(String deviceId) =>
      _bluetooth.connect(deviceId);

  Future<void> disconnect(String deviceId) => _bluetooth.disconnect(deviceId);

  DeviceSighting _classify(BleScanRecord record) {
    final manufacturer = BluetoothDeviceInspector.resolveManufacturer(
      record.id,
      record.manufacturerData,
    );
    final deviceType = BluetoothDeviceInspector.resolveDeviceType(
      record.name,
      manufacturer,
      record.serviceUuids,
    );
    final hasName = record.name.isNotEmpty;
    return DeviceSighting(
      hasAdvertisedName: hasName,
      device: ScannedDeviceModel(
        id: record.id,
        name: hasName
            ? record.name
            : _inferDeviceName(manufacturer, deviceType, record.id),
        manufacturer: manufacturer,
        deviceType: deviceType,
        rssi: record.rssi,
        txPower: record.txPower,
        isConnectable: record.isConnectable,
        serviceUuids: record.serviceUuids,
        lastSeen: record.timestamp,
        firstSeen: record.timestamp,
      ),
    );
  }

  String _inferDeviceName(String manufacturer, String deviceType, String mac) {
    final macSuffix = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;

    if (manufacturer.contains('Apple')) {
      return 'Apple Device ($macSuffix)';
    } else if (manufacturer.contains('Samsung')) {
      return 'Samsung Device ($macSuffix)';
    } else if (manufacturer.contains('Espressif')) {
      return 'ESP32 Module ($macSuffix)';
    } else if (manufacturer.contains('Sony') || manufacturer.contains('Bose')) {
      return '$manufacturer Headset ($macSuffix)';
    } else if (deviceType.contains('Audio')) {
      return 'Wireless Earpiece ($macSuffix)';
    } else if (deviceType.contains('Wearable')) {
      return 'Smartband / Watch ($macSuffix)';
    } else {
      return 'BLE Device ($macSuffix)';
    }
  }
}

final scannerRepositoryProvider = Provider<ScannerRepository>(
  (ref) => ScannerRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
