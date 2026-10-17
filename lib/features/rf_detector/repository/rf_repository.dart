import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';

/// One received 2.4 GHz packet.
class RfPacket {
  const RfPacket({
    required this.sourceId,
    required this.sourceName,
    required this.rssi,
    required this.timestamp,
    required this.isExamGuardNode,
  });

  final String sourceId;
  final String sourceName;
  final int rssi;
  final DateTime timestamp;

  /// True when the sender's name starts with [RfRepository.nodeNamePrefix].
  /// Generic ESP32 boards are NOT nodes: a DIY ESP32 is a typical cheating
  /// device.
  final bool isExamGuardNode;
}

/// Live 2.4 GHz activity from the phone's Bluetooth radio.
class RfRepository {
  RfRepository(this._bluetooth, this._permissions);

  static const String _scanOwner = 'rf_detector';

  /// Advertised-name prefix of ExamGuard hardware nodes (case-insensitive).
  static const String nodeNamePrefix = 'examguard';

  static bool isExamGuardNodeName(String name) =>
      name.trim().toLowerCase().startsWith(nodeNamePrefix);

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  Future<bool> isBluetoothOn() async =>
      await _bluetooth.adapterStatus().first == BleAdapterStatus.on;

  /// Current adapter status, then every change.
  Stream<BleAdapterStatus> adapterStatus() => _bluetooth.adapterStatus();

  /// Throws [BleScanException] when the radio cannot start scanning.
  Future<void> startScan() => _bluetooth.startScan(_scanOwner);

  Future<void> stopScan() => _bluetooth.stopScan(_scanOwner);

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
      isExamGuardNode: isExamGuardNodeName(r.name),
    ),
  );
}

final rfRepositoryProvider = Provider<RfRepository>(
  (ref) => RfRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
