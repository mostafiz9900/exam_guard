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

  /// True when the sender advertises as an ExamGuard ESP32 hardware node.
  final bool isExamGuardNode;
}

/// Live 2.4 GHz activity from the phone's Bluetooth radio.
class RfRepository {
  RfRepository(this._bluetooth, this._permissions);

  static const String _scanOwner = 'rf_detector';
  static const List<String> _nodeKeywords = ['examguard', 'esp32', 'rf-node'];

  final IBluetoothService _bluetooth;
  final IPermissionService _permissions;

  Future<AppPermissionStatus> requestPermissions() =>
      _permissions.requestBluetoothScan();

  Future<bool> isBluetoothOn() async =>
      await _bluetooth.adapterStatus().first == BleAdapterStatus.on;

  Future<void> startScan() => _bluetooth.startScan(_scanOwner);

  Future<void> stopScan() => _bluetooth.stopScan(_scanOwner);

  Stream<RfPacket> packets() => _bluetooth.scanRecords.map(
    (r) => RfPacket(
      sourceId: r.id,
      sourceName: r.name,
      rssi: r.rssi,
      timestamp: r.timestamp,
      isExamGuardNode: _nodeKeywords.any(r.name.toLowerCase().contains),
    ),
  );
}

final rfRepositoryProvider = Provider<RfRepository>(
  (ref) => RfRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);
