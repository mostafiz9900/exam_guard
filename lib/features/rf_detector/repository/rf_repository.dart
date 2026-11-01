import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';

/// One received 2.4 GHz packet.
class RfPacket {
  const RfPacket({
    required this.sourceId,
    required this.sourceName,
    required this.rssi,
    required this.timestamp,
    required this.isPaharaNode,
  });

  final String sourceId;
  final String sourceName;
  final int rssi;
  final DateTime timestamp;

  /// True when the sender is a Pahara sensor node (by its name).
  /// Generic ESP32 boards are NOT nodes: a DIY ESP32 is a typical cheating
  /// device.
  final bool isPaharaNode;
}

/// Live 2.4 GHz activity from the phone's Bluetooth radio.
class RfRepository {
  RfRepository(
    this._bluetooth,
    this._permissions, {
    IClassicBluetoothService? classic,
    IWifiScanService? wifi,
  }) : _classic = classic,
       _wifi = wifi;

  static const String _scanOwner = 'rf_detector';

  /// True for a Pahara sensor node's advertised name (see [AppBrand]).
  static bool isPaharaNodeName(String name) => AppBrand.isNodeName(name);

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;
  final IClassicBluetoothService? _classic;
  final IWifiScanService? _wifi;

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  Future<bool> isBluetoothOn() async =>
      await _bluetooth.adapterStatus().first == BleAdapterStatus.on;

  /// Current adapter status, then every change.
  Stream<BleAdapterStatus> adapterStatus() => _bluetooth.adapterStatus();

  /// Throws [BleScanException] when the radio cannot start scanning.
  /// Classic Bluetooth inquiries starve BLE for ~12 s, which made the meter
  /// read "0 transmitters / QUIET" every half minute; pause them (and Wi-Fi
  /// scans) while the meter is open.
  Future<void> startScan() async {
    await _classic?.suspend(_scanOwner);
    await _wifi?.suspend(_scanOwner);
    await _bluetooth.startScan(_scanOwner);
  }

  Future<void> stopScan() async {
    try {
      await _bluetooth.stopScan(_scanOwner);
    } finally {
      await _classic?.resume(_scanOwner);
      await _wifi?.resume(_scanOwner);
    }
  }

  /// What currently stops the scan from receiving anything (e.g. Location
  /// off), or null when it works. Current value first, then every change.
  /// The scan resumes by itself once the problem clears.
  Stream<BleScanError?> scanProblem() => _bluetooth.scanProblem;

  /// Opens the system Location settings.
  Future<bool> openLocationSettings() => _permissions.openLocationSettings();

  /// Scan failures arrive as [BleScanException] errors.
  Stream<RfPacket> packets() => _bluetooth.scanRecords.map(
    (r) => RfPacket(
      sourceId: r.id,
      sourceName: r.name,
      rssi: r.rssi,
      timestamp: r.timestamp,
      isPaharaNode: isPaharaNodeName(r.name),
    ),
  );
}

final rfRepositoryProvider = Provider<RfRepository>(
  (ref) => RfRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
    classic: ref.watch(classicBluetoothServiceProvider),
    wifi: ref.watch(wifiScanServiceProvider),
  ),
);
