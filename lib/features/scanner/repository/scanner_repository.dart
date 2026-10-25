import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';

/// What a device has advertised so far. Android delivers the advertisement
/// and the scan response as separate packets, each carrying only part of the
/// data, so classifying a single packet made names and categories flicker.
class _AdvertisedProfile {
  String name = '';
  int? txPower;
  final Map<int, List<int>> manufacturerData = {};
  final Set<String> serviceUuids = {};

  /// Every packet so far had its content hidden by iOS.
  bool? payloadHidden;

  void merge(BleScanRecord r) {
    payloadHidden = (payloadHidden ?? true) && r.isPayloadHidden;
    if (r.name.isNotEmpty) name = r.name;
    txPower = r.txPower ?? txPower;
    manufacturerData.addAll(r.manufacturerData);
    serviceUuids.addAll(r.serviceUuids);
  }
}

/// Live device discovery for the wireless scanner: BLE advertisements,
/// classic Bluetooth inquiry and Wi-Fi access point scans, all mapped to
/// [ScannedDeviceModel].
class ScannerRepository {
  ScannerRepository(
    this._bluetooth,
    this._permissions,
    this._classic,
    this._wifi,
  );

  static const String _scanOwner = 'wireless_scanner';

  /// Rotating random addresses make new ids all the time; cap the cache.
  static const int _maxProfiles = 1000;

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;
  final IClassicBluetoothService _classic;
  final IWifiScanService _wifi;
  final Map<String, _AdvertisedProfile> _profiles = {};

  Future<bool> isSupported() => _bluetooth.isSupported();

  Stream<bool> bluetoothOn() =>
      _bluetooth.adapterStatus().map((s) => s == BleAdapterStatus.on);

  Future<void> turnOnBluetooth() => _bluetooth.turnOn();

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  /// What currently stops the scan from finding devices (e.g. Location is
  /// off), or null. Emits the current value first, then every change. The
  /// shared scan resumes by itself once the problem clears.
  Stream<BleScanError?> scanProblem() => _bluetooth.scanProblem;

  /// Opens the system Location settings. False where that isn't possible.
  Future<bool> openLocationSettings() => _permissions.openLocationSettings();

  /// Opens this app's page in the OS settings, where a permanently denied
  /// permission can be granted again.
  Future<bool> openAppSettings() => _permissions.openSettings();

  /// Throws [BleScanException] when scanning cannot start.
  Future<void> startScan() => _bluetooth.startScan(_scanOwner);

  Future<void> stopScan() => _bluetooth.stopScan(_scanOwner);

  /// Every advertisement received while scanning, classified using
  /// everything the device has advertised so far. Errors are
  /// [BleScanException]s.
  Stream<ScannedDeviceModel> sightings() =>
      _bluetooth.scanRecords.map(_classify);

  // ── Classic Bluetooth ────────────────────────────────────────────────

  /// False where classic discovery isn't available (iOS).
  bool get isClassicSupported => _classic.isSupported;

  Future<void> startClassicDiscovery() => _classic.start(_scanOwner);

  Future<void> stopClassicDiscovery() => _classic.stop(_scanOwner);

  /// Classic Bluetooth devices found by inquiry (each repeats per cycle).
  Stream<ScannedDeviceModel> classicSightings() =>
      _classic.discoveries.map(classicToDevice);

  // ── Wi-Fi ────────────────────────────────────────────────────────────

  /// False where apps can't scan for Wi-Fi (iOS).
  bool get isWifiSupported => _wifi.isSupported;

  Future<void> startWifiScan() => _wifi.start(_scanOwner);

  Future<void> stopWifiScan() => _wifi.stop(_scanOwner);

  /// Every access point from each completed Wi-Fi scan.
  Stream<List<ScannedDeviceModel>> wifiSightings() =>
      _wifi.results.map(wifiToDevices);

  /// Why Wi-Fi scanning isn't working, or null. Current value first.
  Stream<WifiScanProblem?> wifiProblem() => _wifi.problem;

  Future<BleConnectionInfo> connect(String deviceId) =>
      _bluetooth.connect(deviceId);

  Future<void> disconnect(String deviceId) => _bluetooth.disconnect(deviceId);

  /// Paired / connected devices' names by id (see
  /// [IBluetoothService.knownDeviceNames]).
  Future<Map<String, String>> knownDeviceNames() =>
      _bluetooth.knownDeviceNames();

  /// Maps one classic Bluetooth inquiry result.
  static ScannedDeviceModel classicToDevice(ClassicBtRecord r) {
    final address = r.address.toUpperCase();
    final vendor = BluetoothDeviceInspector.resolveManufacturer(address, {});
    final manufacturer = vendor == 'Generic BLE Hardware'
        ? ScannedDeviceModel.genericBluetoothManufacturer
        : vendor;
    final name = r.name.trim();
    return ScannedDeviceModel(
      id: address,
      name: name,
      manufacturer: manufacturer,
      deviceType: WirelessClassifier.classicDeviceType(
        name: name,
        manufacturer: manufacturer,
        majorDeviceClass: r.majorDeviceClass,
        deviceClass: r.deviceClass,
      ),
      // Inquiry results without a level are treated as far away.
      rssi: r.rssi ?? -100,
      isConnectable: false,
      lastSeen: r.timestamp,
      firstSeen: r.timestamp,
      transport: DeviceTransport.classic,
      isHighSuspicion: WirelessClassifier.isSpyEarpieceClass(r.deviceClass),
    );
  }

  /// Maps one Wi-Fi scan. The whole scan is needed to tell a router's
  /// virtual access points from phone hotspots.
  static List<ScannedDeviceModel> wifiToDevices(List<WifiNetworkRecord> scan) {
    final bssids = [for (final r in scan) r.bssid];
    return [
      for (final r in scan)
        if (r.bssid.trim().isNotEmpty)
          ScannedDeviceModel(
            id: '${ScannedDeviceModel.wifiIdPrefix}${r.bssid.toUpperCase()}',
            name: r.ssid.trim(),
            manufacturer: ScannedDeviceModel.wifiManufacturer,
            deviceType: WirelessClassifier.wifiDeviceType(
              r.ssid,
              r.bssid,
              scanBssids: bssids,
            ),
            rssi: r.rssi,
            isConnectable: false,
            lastSeen: r.timestamp,
            firstSeen: r.timestamp,
            transport: DeviceTransport.wifi,
          ),
    ];
  }

  ScannedDeviceModel _classify(BleScanRecord record) {
    if (_profiles.length >= _maxProfiles && !_profiles.containsKey(record.id)) {
      _profiles.clear();
    }
    final profile = _profiles.putIfAbsent(record.id, _AdvertisedProfile.new)
      ..merge(record);
    final serviceUuids = profile.serviceUuids.toList();

    final hidden = profile.payloadHidden ?? false;
    final manufacturer = hidden
        ? 'Apple Inc.'
        : BluetoothDeviceInspector.resolveManufacturer(
            record.id,
            profile.manufacturerData,
          );
    return ScannedDeviceModel(
      id: record.id,
      name: profile.name,
      manufacturer: manufacturer,
      deviceType: hidden
          ? ScannedDeviceModel.appleHiddenType
          : BluetoothDeviceInspector.resolveDeviceType(
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
    ref.watch(classicBluetoothServiceProvider),
    ref.watch(wifiScanServiceProvider),
  ),
);
