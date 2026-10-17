import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';

/// What a device has advertised so far. Android delivers the advertisement
/// and the scan response as separate packets, each carrying only part of the
/// data, so classifying a single packet made names and categories flicker.
class _AdvertisedProfile {
  String name = '';
  int? txPower;
  final Map<int, List<int>> manufacturerData = {};
  final Set<String> serviceUuids = {};

  void merge(BleScanRecord r) {
    if (r.name.isNotEmpty) name = r.name;
    txPower = r.txPower ?? txPower;
    manufacturerData.addAll(r.manufacturerData);
    serviceUuids.addAll(r.serviceUuids);
  }
}

/// Live BLE device discovery for the wireless scanner.
class ScannerRepository {
  ScannerRepository(this._bluetooth, this._permissions);

  static const String _scanOwner = 'wireless_scanner';

  /// Rotating random addresses make new ids all the time; cap the cache.
  static const int _maxProfiles = 1000;

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;
  final Map<String, _AdvertisedProfile> _profiles = {};

  Future<bool> isSupported() => _bluetooth.isSupported();

  Stream<bool> bluetoothOn() =>
      _bluetooth.adapterStatus().map((s) => s == BleAdapterStatus.on);

  Future<void> turnOnBluetooth() => _bluetooth.turnOn();

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  /// Throws [BleScanException] when scanning cannot start.
  Future<void> startScan() => _bluetooth.startScan(_scanOwner);

  Future<void> stopScan() => _bluetooth.stopScan(_scanOwner);

  /// Every advertisement received while scanning, classified using
  /// everything the device has advertised so far. Errors are
  /// [BleScanException]s.
  Stream<ScannedDeviceModel> sightings() =>
      _bluetooth.scanRecords.map(_classify);

  Future<BleConnectionInfo> connect(String deviceId) =>
      _bluetooth.connect(deviceId);

  Future<void> disconnect(String deviceId) => _bluetooth.disconnect(deviceId);

  ScannedDeviceModel _classify(BleScanRecord record) {
    if (_profiles.length >= _maxProfiles && !_profiles.containsKey(record.id)) {
      _profiles.clear();
    }
    final profile = _profiles.putIfAbsent(record.id, _AdvertisedProfile.new)
      ..merge(record);
    final serviceUuids = profile.serviceUuids.toList();

    final manufacturer = BluetoothDeviceInspector.resolveManufacturer(
      record.id,
      profile.manufacturerData,
    );
    return ScannedDeviceModel(
      id: record.id,
      name: profile.name,
      manufacturer: manufacturer,
      deviceType: BluetoothDeviceInspector.resolveDeviceType(
        profile.name,
        manufacturer,
        serviceUuids,
        profile.manufacturerData,
      ),
      rssi: record.rssi,
      txPower: profile.txPower,
      isConnectable: record.isConnectable,
      serviceUuids: serviceUuids,
      lastSeen: record.timestamp,
      firstSeen: record.timestamp,
    );
  }
}

final scannerRepositoryProvider = Provider<ScannerRepository>(
  (ref) => ScannerRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
