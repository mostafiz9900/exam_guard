import 'dart:async';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

class FakeFinderBluetooth implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();
  final problems = StreamController<BleScanError?>.broadcast();
  final adapter = StreamController<BleAdapterStatus>.broadcast();
  final owners = <String>{};
  BleScanException? startError;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => adapter.stream;

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {
    if (startError != null) throw startError!;
    owners.add(owner);
  }

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      throw Exception('not supported');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {}
}

class FakeWakelock implements IWakelockService {
  final owners = <String>{};
  final calls = <String>[];

  @override
  Future<void> enable(String owner) async {
    owners.add(owner);
    calls.add('enable:$owner');
  }

  @override
  Future<void> disable(String owner) async {
    owners.remove(owner);
    calls.add('disable:$owner');
  }

  @override
  bool get isEnabled => owners.isNotEmpty;
}

class FakeHaptics implements IHapticService {
  final pulses = <HapticStrength>[];
  var alerts = 0;

  @override
  Future<void> pulse(HapticStrength strength) async => pulses.add(strength);

  @override
  Future<void> alertPattern() async => alerts++;
}

BleScanRecord bleRecord(String id, int rssi, [DateTime? at]) => BleScanRecord(
  id: id,
  name: 'Phone',
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: const {},
  timestamp: at ?? DateTime.now(),
);

ScannedDeviceModel bleDevice(
  String id, {
  DeviceTransport transport = DeviceTransport.ble,
}) => ScannedDeviceModel(
  id: id,
  name: 'Device $id',
  rssi: -70,
  lastSeen: DateTime(2026),
  firstSeen: DateTime(2026),
  transport: transport,
);

/// Scanner stand-in for the finders: no scanning, configurable aliases.
class FakeScanner extends ScannerViewModel {
  FakeScanner([Map<String, Set<String>>? aliases]) : aliases = aliases ?? {};

  /// Device id → every address of that device.
  final Map<String, Set<String>> aliases;
  final asked = <String>[];

  @override
  ScannerState build() => ScannerState();

  @override
  Set<String> aliasesOf(String deviceId) {
    asked.add(deviceId);
    return {...?aliases[deviceId], deviceId};
  }

  /// The scanner learned something new about addresses (rotation, group).
  void changeIdentity(String deviceId, Set<String> addresses) {
    aliases[deviceId] = addresses;
    state = state.copyWith(identityVersion: state.identityVersion + 1);
  }
}
