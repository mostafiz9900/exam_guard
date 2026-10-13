import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeBluetoothService implements IBluetoothService {
  final records = StreamController<BleScanRecord>.broadcast();
  final owners = <String>{};

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Future<void> startScan(String owner) async => owners.add(owner);

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      throw Exception('connection refused');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async => records.close();
}

class GrantedPermissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}

BleScanRecord record(String id, int rssi) => BleScanRecord(
  id: id,
  name: 'Phone $id',
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: const {},
  timestamp: DateTime.now(),
);

void main() {
  late FakeBluetoothService bluetooth;
  late ProviderContainer container;

  setUp(() async {
    bluetooth = FakeBluetoothService();
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        permissionServiceProvider.overrideWithValue(GrantedPermissions()),
      ],
    );
    container.listen(scannerViewModelProvider, (_, _) {});
    await pumpEventQueue();
  });

  tearDown(() => container.dispose());

  test('starts a live scan and shows no devices until one advertises', () {
    final state = container.read(scannerViewModelProvider);
    expect(state.isScanning, isTrue);
    expect(state.devices, isEmpty);
    expect(bluetooth.owners, contains('wireless_scanner'));
  });

  test('every advertisement updates the device list immediately', () async {
    bluetooth.records.add(record('AA:BB', -70));
    await pumpEventQueue();
    expect(container.read(scannerViewModelProvider).devices.single.rssi, -70);

    bluetooth.records.add(record('AA:BB', -50));
    await pumpEventQueue();
    final rssi = container.read(scannerViewModelProvider).devices.single.rssi;
    expect(rssi, greaterThan(-70));
  });

  test('a failed connection is not shown as connected', () async {
    bluetooth.records.add(record('AA:BB', -60));
    await pumpEventQueue();

    await container
        .read(scannerViewModelProvider.notifier)
        .probeDeviceConnection('AA:BB');

    final state = container.read(scannerViewModelProvider);
    expect(state.devices.single.isConnected, isFalse);
    expect(state.devices.single.batteryLevel, isNull);
    expect(state.errorMessage, contains('Could not connect'));
  });

  test('stopping the scan releases the radio', () async {
    await container
        .read(scannerViewModelProvider.notifier)
        .toggleScanning(false);
    expect(bluetooth.owners, isEmpty);
  });
}
