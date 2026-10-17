import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeBluetoothService implements IBluetoothService {
  final records = StreamController<BleScanRecord>.broadcast();
  final owners = <String>{};
  BleScanException? startError;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Future<void> startScan(String owner) async {
    if (startError != null) throw startError!;
    owners.add(owner);
  }

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
  int requests = 0;

  @override
  Future<AppPermissionStatus> requestBluetoothScan() async {
    requests++;
    return AppPermissionStatus.granted;
  }

  @override
  Future<bool> openSettings() async => true;
}

BleScanRecord record(
  String id,
  int rssi, {
  String? name,
  DateTime? at,
  Map<int, List<int>> manufacturerData = const {},
}) => BleScanRecord(
  id: id,
  name: name ?? 'Phone $id',
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: manufacturerData,
  timestamp: at ?? DateTime.now(),
);

void main() {
  late FakeBluetoothService bluetooth;
  late GrantedPermissions permissions;
  late ProviderContainer container;

  setUp(() async {
    bluetooth = FakeBluetoothService();
    permissions = GrantedPermissions();
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        permissionServiceProvider.overrideWithValue(permissions),
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
    expect(state.errorMessage, 'scan_err_connect_failed');
    expect(state.errorArgs['name'], isNotEmpty);
  });

  test('stopping the scan releases the radio', () async {
    await container
        .read(scannerViewModelProvider.notifier)
        .toggleScanning(false);
    expect(bluetooth.owners, isEmpty);
  });

  test('a nameless packet does not erase the advertised name', () async {
    bluetooth.records.add(record('AA:BB', -60, name: 'Galaxy Buds2'));
    await pumpEventQueue();
    bluetooth.records.add(record('AA:BB', -60, name: ''));
    await pumpEventQueue();

    final device = container.read(scannerViewModelProvider).devices.single;
    expect(device.displayName, 'Galaxy Buds2');
    expect(device.deviceType, contains('Audio'));
  });

  test('a rotated random address replaces its silent old entry', () async {
    final tenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 10));
    bluetooth.records.add(
      record('11:11', -60, name: 'AirPods Pro', at: tenSecondsAgo),
    );
    await pumpEventQueue();
    bluetooth.records.add(record('22:22', -62, name: 'AirPods Pro'));
    await pumpEventQueue();

    final devices = container.read(scannerViewModelProvider).devices;
    expect(devices.map((d) => d.id), ['22:22']);
  });

  test(
    'two identical devices that are both advertising stay separate',
    () async {
      bluetooth.records.add(record('11:11', -60, name: 'AirPods Pro'));
      bluetooth.records.add(record('22:22', -62, name: 'AirPods Pro'));
      await pumpEventQueue();

      expect(container.read(scannerViewModelProvider).devices, hasLength(2));
    },
  );

  test('a scan that cannot start shows why instead of a silent LIVE', () async {
    final notifier = container.read(scannerViewModelProvider.notifier);
    await notifier.toggleScanning(false);
    bluetooth.startError = const BleScanException('Radio busy');

    await notifier.toggleScanning(true);

    final state = container.read(scannerViewModelProvider);
    expect(state.isScanning, isFalse);
    expect(state.errorMessage, 'scan_err_detail');
    expect(state.errorArgs, {'detail': 'Radio busy'});
  });

  test('a known scan failure maps to its own message key', () async {
    final notifier = container.read(scannerViewModelProvider.notifier);
    await notifier.toggleScanning(false);
    bluetooth.startError = const BleScanException(
      'Turn on Location (GPS)',
      code: BleScanError.locationOff,
    );

    await notifier.toggleScanning(true);

    expect(
      container.read(scannerViewModelProvider).errorMessage,
      'scan_err_location',
    );
  });

  test('overlapping start requests ask for permissions once', () async {
    final notifier = container.read(scannerViewModelProvider.notifier);
    await notifier.toggleScanning(false);
    permissions.requests = 0;

    await Future.wait([
      notifier.toggleScanning(true),
      notifier.toggleScanning(true),
    ]);

    expect(permissions.requests, 1);
    expect(container.read(scannerViewModelProvider).isScanning, isTrue);
  });

  group('classifier', () {
    test('Device Information service alone is not an earpiece', () {
      expect(
        BluetoothDeviceInspector.resolveDeviceType('', 'Generic BLE Hardware', [
          '0000180A-0000-1000-8000-00805F9B34FB',
        ]),
        isNot(contains('Audio')),
      );
    });

    test('nameless AirPods are recognised from Apple proximity pairing', () {
      expect(
        BluetoothDeviceInspector.resolveDeviceType('', 'Apple Inc.', [], {
          0x004C: [0x07, 0x19, 0x01],
        }),
        contains('Audio'),
      );
    });

    test('a Huawei watch is not a Wi-Fi hotspot', () {
      expect(
        BluetoothDeviceInspector.resolveDeviceType(
          'HUAWEI WATCH GT 4',
          'Generic BLE Hardware',
          [],
        ),
        contains('Wearable'),
      );
    });
  });
}
