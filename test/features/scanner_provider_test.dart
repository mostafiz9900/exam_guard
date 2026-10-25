import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeBluetoothService implements IBluetoothService {

  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
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

  final problems = StreamController<BleScanError?>.broadcast();

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
      throw Exception('connection refused');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async => records.close();
}

class GrantedPermissions implements IPermissionService {
  int requests = 0;
  int locationSettingsOpened = 0;
  bool canOpenLocationSettings = true;

  @override
  Future<AppPermissionStatus> requestBluetoothScan() async {
    requests++;
    return AppPermissionStatus.granted;
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return canOpenLocationSettings;
  }
}

BleScanRecord record(
  String id,
  int rssi, {
  String? name,
  DateTime? at,
  Map<int, List<int>> manufacturerData = const {},
  List<String> serviceUuids = const [],
}) => BleScanRecord(
  id: id,
  name: name ?? 'Phone $id',
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: serviceUuids,
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

  test('a new device shows at once; its values update within 250 ms', () async {
    bluetooth.records.add(record('AA:BB', -70));
    await pumpEventQueue();
    expect(container.read(scannerViewModelProvider).devices.single.rssi, -70);

    bluetooth.records.add(record('AA:BB', -50));
    await pumpEventQueue();
    // Value updates are coalesced (at most ~4 publishes a second).
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
    // A failed connect is a one-off notice, never a blocking scan error.
    expect(state.errorMessage, isNull);
    expect(state.isScanning, isTrue);
    expect(state.noticeKey, 'scan_err_connect_failed');
    expect(state.noticeArgs['name'], isNotEmpty);
  });

  test('every notice gets a new id, even when it repeats', () async {
    bluetooth.records.add(record('AA:BB', -60));
    await pumpEventQueue();
    final notifier = container.read(scannerViewModelProvider.notifier);

    await notifier.probeDeviceConnection('AA:BB');
    final first = container.read(scannerViewModelProvider).noticeId;
    await notifier.probeDeviceConnection('AA:BB');
    final second = container.read(scannerViewModelProvider).noticeId;

    expect(second, greaterThan(first));
    expect(container.read(scannerViewModelProvider).errorMessage, isNull);
  });

  group('location off', () {
    test('isLocationOff follows the scan problem stream', () async {
      expect(container.read(scannerViewModelProvider).isLocationOff, isFalse);

      bluetooth.problems.add(BleScanError.locationOff);
      await pumpEventQueue();
      var state = container.read(scannerViewModelProvider);
      expect(state.isLocationOff, isTrue);
      expect(state.errorMessage, isNull);
      // The owner stays registered so core resumes the scan by itself.
      expect(state.isScanning, isTrue);
      expect(bluetooth.owners, contains('wireless_scanner'));
      expect(
        state.emptyReason(DeviceFilter.all),
        ScannerEmptyReason.locationOff,
      );

      bluetooth.problems.add(null);
      await pumpEventQueue();
      state = container.read(scannerViewModelProvider);
      expect(state.isLocationOff, isFalse);
      expect(state.isScanning, isTrue);
      expect(bluetooth.owners, contains('wireless_scanner'));
    });

    test('openLocationSettings opens the system page', () async {
      await container
          .read(scannerViewModelProvider.notifier)
          .openLocationSettings();
      expect(permissions.locationSettingsOpened, 1);
      expect(container.read(scannerViewModelProvider).noticeKey, isNull);
    });

    test('a notice explains when Location settings cannot open', () async {
      permissions.canOpenLocationSettings = false;
      await container
          .read(scannerViewModelProvider.notifier)
          .openLocationSettings();
      final state = container.read(scannerViewModelProvider);
      expect(state.noticeKey, 'scan_notice_location_settings');
      expect(state.errorMessage, isNull);
    });
  });

  test(
    'simultaneous nameless addresses of one phone show as one group',
    () async {
      final now = DateTime.now();
      for (final id in ['AA:01', 'AA:02', 'AA:03']) {
        bluetooth.records.add(
          record(
            id,
            id == 'AA:02' ? -50 : -49,
            name: '',
            at: now,
            manufacturerData: const {
              0x004C: [0x10, 0x05, 0x01],
            },
          ),
        );
      }
      await pumpEventQueue();

      final state = container.read(scannerViewModelProvider);
      expect(state.devices, hasLength(3));
      expect(state.groups, hasLength(1));
      expect(state.groups.single.members.map((d) => d.id).toSet(), {
        'AA:01',
        'AA:02',
        'AA:03',
      });
      expect(state.visibleGroups(DeviceFilter.all), hasLength(1));
    },
  );

  group('empty reasons', () {
    test('a filter that hides everything is not "scanning"', () async {
      bluetooth.records.add(record('AA:BB', -80, name: 'Galaxy S24'));
      await pumpEventQueue();

      final state = container.read(scannerViewModelProvider);
      expect(state.emptyReason(DeviceFilter.all), isNull);
      expect(
        state.emptyReason(DeviceFilter.covertEsp),
        ScannerEmptyReason.filteredOut,
      );
    });

    test('a room boundary that hides everything says so', () async {
      bluetooth.records.add(record('AA:BB', -98, name: 'Far phone'));
      await pumpEventQueue();
      container
          .read(scannerViewModelProvider.notifier)
          .toggleRoomBoundaryMode(true);

      final state = container.read(scannerViewModelProvider);
      expect(state.activeGroups, isEmpty);
      expect(state.groups, hasLength(1));
      expect(
        state.emptyReason(DeviceFilter.all),
        ScannerEmptyReason.outsideBoundary,
      );
    });

    test('nothing heard yet while scanning is "waiting"', () {
      expect(
        container.read(scannerViewModelProvider).emptyReason(DeviceFilter.all),
        ScannerEmptyReason.waiting,
      );
    });
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

  group('identity (aliasesOf / identityVersion)', () {
    ScannerViewModel vm() => container.read(scannerViewModelProvider.notifier);
    int version() => container.read(scannerViewModelProvider).identityVersion;

    test('a rotated address is an alias of the old one and back', () async {
      final tenSecondsAgo = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      bluetooth.records.add(
        record('11:11', -60, name: 'AirPods Pro', at: tenSecondsAgo),
      );
      await pumpEventQueue();
      expect(vm().aliasesOf('11:11'), {'11:11'});
      final before = version();

      bluetooth.records.add(record('22:22', -62, name: 'AirPods Pro'));
      await pumpEventQueue();

      expect(version(), greaterThan(before));
      // The old address is gone from the list but still resolves.
      expect(vm().aliasesOf('11:11'), {'11:11', '22:22'});
      expect(vm().aliasesOf('22:22'), {'11:11', '22:22'});
      expect(vm().aliasesOf('99:99'), {'99:99'});
    });

    test('a second rotation keeps the chain', () async {
      final t = DateTime.now();
      bluetooth.records.add(
        record(
          '11:11',
          -60,
          name: 'Buds',
          at: t.subtract(const Duration(seconds: 20)),
        ),
      );
      await pumpEventQueue();
      bluetooth.records.add(
        record(
          '22:22',
          -60,
          name: 'Buds',
          at: t.subtract(const Duration(seconds: 10)),
        ),
      );
      await pumpEventQueue();
      bluetooth.records.add(record('33:33', -60, name: 'Buds'));
      await pumpEventQueue();
      expect(vm().aliasesOf('11:11'), {'11:11', '22:22', '33:33'});
    });

    test('members of a group are aliases of each other', () async {
      const apple = {
        0x004C: [0x10, 0x05, 0x01],
      };
      final t = DateTime.now();
      bluetooth.records.add(
        record('B1', -60, name: '', at: t, manufacturerData: apple),
      );
      await pumpEventQueue();
      final single = version();
      expect(vm().aliasesOf('B1'), {'B1'});

      bluetooth.records.add(
        record('B2', -61, name: '', at: t, manufacturerData: apple),
      );
      await pumpEventQueue();
      expect(
        container
            .read(scannerViewModelProvider)
            .groups
            .where((g) => g.isGrouped),
        hasLength(1),
      );
      expect(version(), greaterThan(single));
      expect(vm().aliasesOf('B1'), {'B1', 'B2'});
      expect(vm().aliasesOf('B2'), {'B1', 'B2'});

      // A value-only update does not change identity.
      final grouped = version();
      bluetooth.records.add(
        record('B1', -59, name: '', at: t, manufacturerData: apple),
      );
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(version(), grouped);
    });
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
      'Too frequently',
      code: BleScanError.throttled,
    );

    await notifier.toggleScanning(true);

    expect(
      container.read(scannerViewModelProvider).errorMessage,
      'scan_err_throttled',
    );
  });

  test('Location off at start is not a scan failure', () async {
    final notifier = container.read(scannerViewModelProvider.notifier);
    await notifier.toggleScanning(false);
    bluetooth.startError = const BleScanException(
      'Turn on Location (GPS)',
      code: BleScanError.locationOff,
    );

    await notifier.toggleScanning(true);

    final state = container.read(scannerViewModelProvider);
    expect(state.errorMessage, isNull);
    expect(state.isLocationOff, isTrue);
    expect(state.isScanning, isTrue);
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
