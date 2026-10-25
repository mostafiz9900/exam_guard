// Scanner view model: classic Bluetooth / Wi-Fi merge, trusted devices,
// baseline and new-device alerts.

import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Bluetooth implements IBluetoothService {

  /// Names the OS knows (paired / connected), by id.
  Map<String, String> known = const {};

  /// Name each device reveals when connected to.
  final gattNames = <String, String>{};
  final connects = <String>[];
  final disconnects = <String>[];

  @override
  Future<Map<String, String>> knownDeviceNames() async => known;
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
  Stream<BleScanError?> get scanProblem => const Stream.empty();

  @override
  Future<void> startScan(String owner) async => owners.add(owner);

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async {
    connects.add(deviceId);
    return BleConnectionInfo(gattName: gattNames[deviceId]);
  }

  @override
  Future<void> disconnect(String deviceId) async => disconnects.add(deviceId);

  @override
  Future<void> dispose() async {}
}

class _Classic implements IClassicBluetoothService {
  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  final records = StreamController<ClassicBtRecord>.broadcast();
  final owners = <String>{};

  @override
  bool get isSupported => true;

  @override
  Stream<ClassicBtRecord> get discoveries => records.stream;

  @override
  Future<void> start(String owner) async => owners.add(owner);

  @override
  Future<void> stop(String owner) async => owners.remove(owner);

  @override
  Future<void> dispose() async {}
}

class _Wifi implements IWifiScanService {
  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  final scans = StreamController<List<WifiNetworkRecord>>.broadcast();
  final problems = StreamController<WifiScanProblem?>.broadcast();
  final owners = <String>{};

  @override
  bool get isSupported => true;

  @override
  Stream<List<WifiNetworkRecord>> get results => scans.stream;

  @override
  Stream<WifiScanProblem?> get problem => problems.stream;

  @override
  Future<void> start(String owner) async => owners.add(owner);

  @override
  Future<void> stop(String owner) async => owners.remove(owner);

  @override
  Future<void> dispose() async {}
}

class _Permissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Storage implements ILocalStorage {
  final values = <String, Object?>{};

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;

  @override
  T? read<T>(String key) {
    final v = values[key];
    return v is T ? v : null;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Iterable<String> get keys => values.keys;

  @override
  Future<void> dispose() async {}
}

BleScanRecord ble(
  String id,
  int rssi, {
  String name = '',
  required DateTime at,
  Map<int, List<int>> manufacturerData = const {},
}) => BleScanRecord(
  id: id,
  name: name,
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: manufacturerData,
  timestamp: at,
);

ClassicBtRecord classic(
  String mac,
  int rssi, {
  String name = '',
  int? deviceClass,
  DateTime? at,
}) => ClassicBtRecord(
  address: mac,
  name: name,
  rssi: rssi,
  majorDeviceClass: deviceClass == null ? null : deviceClass & 0x1F00,
  deviceClass: deviceClass,
  timestamp: at ?? DateTime.now(),
);

WifiNetworkRecord wifi(String ssid, String bssid, int rssi, {DateTime? at}) =>
    WifiNetworkRecord(
      ssid: ssid,
      bssid: bssid,
      rssi: rssi,
      frequencyMhz: 2437,
      capabilities: '[WPA2-PSK-CCMP][ESS]',
      timestamp: at ?? DateTime.now(),
    );

void main() {
  late _Bluetooth bluetooth;
  late _Classic classicBt;
  late _Wifi wifiScan;
  late _Storage storage;
  late ProviderContainer container;

  ScannerState read() => container.read(scannerViewModelProvider);
  ScannerViewModel vm() => container.read(scannerViewModelProvider.notifier);

  Future<void> setUpContainer({bool withSession = true}) async {
    bluetooth = _Bluetooth();
    classicBt = _Classic();
    wifiScan = _Wifi();
    storage = _Storage();
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        permissionServiceProvider.overrideWithValue(_Permissions()),
        classicBluetoothServiceProvider.overrideWithValue(classicBt),
        wifiScanServiceProvider.overrideWithValue(wifiScan),
        localStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    if (withSession) {
      await container
          .read(sessionViewModelProvider.notifier)
          .createSession(
            instituteName: 'School',
            teacherName: 'Invigilator',
            roomNumber: '12',
          );
    }
    container.listen(scannerViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  /// One BLE device heard twice, [span] apart, starting [after] from now.
  Future<void> bleTwice(
    String id,
    int rssi, {
    String name = 'Phone',
    Duration span = const Duration(seconds: 4),
    Map<int, List<int>> manufacturerData = const {},
  }) async {
    final t = DateTime.now();
    bluetooth.records.add(
      ble(id, rssi, name: name, at: t, manufacturerData: manufacturerData),
    );
    bluetooth.records.add(
      ble(
        id,
        rssi,
        name: name,
        at: t.add(span),
        manufacturerData: manufacturerData,
      ),
    );
    await pumpEventQueue();
  }

  group('sources', () {
    setUp(setUpContainer);

    test(
      'starts classic discovery and Wi-Fi scans with the BLE scan',
      () async {
        expect(bluetooth.owners, {'wireless_scanner'});
        expect(classicBt.owners, {'wireless_scanner'});
        expect(wifiScan.owners, {'wireless_scanner'});

        await vm().toggleScanning(false);
        expect(classicBt.owners, isEmpty);
        expect(wifiScan.owners, isEmpty);
      },
    );

    test('classic and Wi-Fi results join the device list', () async {
      bluetooth.records.add(
        ble('11:11', -60, name: 'Watch', at: DateTime.now()),
      );
      classicBt.records.add(
        classic('00:11:22:33:44:55', -65, deviceClass: 0x0404),
      );
      wifiScan.scans.add([
        wifi('AndroidAP_42', 'AA:BB:CC:DD:EE:FF', -60),
        wifi('School', '00:11:22:33:44:66', -70),
      ]);
      await pumpEventQueue();

      final byId = {for (final d in read().devices) d.id: d};
      expect(byId.keys, {
        '11:11',
        '00:11:22:33:44:55',
        'wifi:AA:BB:CC:DD:EE:FF',
        'wifi:00:11:22:33:44:66',
      });
      expect(byId['00:11:22:33:44:55']!.transport, DeviceTransport.classic);
      expect(byId['00:11:22:33:44:55']!.isHighSuspicion, isTrue);
      expect(byId['wifi:AA:BB:CC:DD:EE:FF']!.transport, DeviceTransport.wifi);
      expect(read().visibleGroups(DeviceFilter.wifiHotspots).map((g) => g.id), [
        'wifi:AA:BB:CC:DD:EE:FF',
      ]);
      expect(ScannerState.countByTransport(read().activeGroups), {
        DeviceTransport.ble: 1,
        DeviceTransport.classic: 1,
        DeviceTransport.wifi: 2,
      });
    });

    test('repeated results update in place and keep what was known', () async {
      final first = DateTime.now();
      classicBt.records.add(
        classic('00:11:22:33:44:55', -70, name: 'Spy Bud', at: first),
      );
      wifiScan.scans.add([
        wifi('AndroidAP_42', 'AA:BB:CC:DD:EE:FF', -60, at: first),
      ]);
      await pumpEventQueue();

      final later = first.add(const Duration(seconds: 30));
      classicBt.records.add(classic('00:11:22:33:44:55', -62, at: later));
      wifiScan.scans.add([
        wifi('AndroidAP_42', 'AA:BB:CC:DD:EE:FF', -50, at: later),
      ]);
      await pumpEventQueue();

      final devices = read().devices;
      expect(devices, hasLength(2));
      final bud = devices.firstWhere((d) => d.id == '00:11:22:33:44:55');
      expect(bud.name, 'Spy Bud');
      expect(bud.rssi, -62);
      expect(bud.firstSeen, first);
      final ap = devices.firstWhere((d) => d.id.startsWith('wifi:'));
      expect(ap.rssi, -50);
      expect(ap.firstSeen, first);
    });

    test('classic and Wi-Fi entries outlive the BLE eviction time', () async {
      final old = DateTime.now().subtract(const Duration(seconds: 40));
      bluetooth.records.add(ble('11:11', -60, name: 'Old', at: old));
      classicBt.records.add(classic('00:11:22:33:44:55', -60, at: old));
      wifiScan.scans.add([wifi('Hall', '00:11:22:33:44:66', -60, at: old)]);
      await pumpEventQueue();
      expect(read().devices, hasLength(3));

      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(read().devices.map((d) => d.id).toSet(), {
        '00:11:22:33:44:55',
        'wifi:00:11:22:33:44:66',
      });
    });

    test('Wi-Fi problems are published', () async {
      wifiScan.problems.add(WifiScanProblem.locationOff);
      await pumpEventQueue();
      expect(read().wifiProblem, WifiScanProblem.locationOff);

      wifiScan.problems.add(null);
      await pumpEventQueue();
      expect(read().wifiProblem, isNull);
    });
  });

  group('device names', () {
    setUp(setUpContainer);

    ScannedDeviceModel device(String id) =>
        read().devices.firstWhere((d) => d.id == id);

    test('a nameless nearby device gets the name stored inside it', () async {
      bluetooth.gattNames['AA:00:00:00:00:01'] = 'Exam Pod';
      bluetooth.records.add(ble('AA:00:00:00:00:01', -60, at: DateTime.now()));
      await pumpEventQueue();
      expect(device('AA:00:00:00:00:01').hasName, isFalse);

      await vm().lookUpNextNameNow();
      expect(bluetooth.connects, ['AA:00:00:00:00:01']);
      expect(bluetooth.disconnects, ['AA:00:00:00:00:01']);
      expect(device('AA:00:00:00:00:01').displayName, 'Exam Pod');
    });

    test('tries each device once, closest first; skips named, far and '
        'Apple devices', () async {
      final now = DateTime.now();
      bluetooth.records
        ..add(ble('AA:00:00:00:00:01', -75, at: now))
        ..add(ble('AA:00:00:00:00:02', -55, at: now))
        ..add(ble('AA:00:00:00:00:03', -50, name: 'Band', at: now))
        ..add(ble('AA:00:00:00:00:04', -95, at: now))
        ..add(
          ble(
            'AA:00:00:00:00:05',
            -50,
            at: now,
            manufacturerData: const {
              0x004C: [0x10, 0x05, 0x01],
            },
          ),
        );
      await pumpEventQueue();

      for (var i = 0; i < 4; i++) {
        await vm().lookUpNextNameNow();
      }
      expect(bluetooth.connects, ['AA:00:00:00:00:02', 'AA:00:00:00:00:01']);
      // Nothing revealed a name: labels stay as they were.
      expect(device('AA:00:00:00:00:02').hasName, isFalse);
    });

    test('no lookup while the user is connected to a device', () async {
      final now = DateTime.now();
      bluetooth.records
        ..add(ble('AA:00:00:00:00:01', -60, at: now))
        ..add(ble('AA:00:00:00:00:02', -60, at: now));
      await pumpEventQueue();
      await vm().probeDeviceConnection('AA:00:00:00:00:01');
      bluetooth.connects.clear();

      await vm().lookUpNextNameNow();
      expect(bluetooth.connects, isEmpty);
    });

    test('packets iOS stripped make an Apple device; any content clears it',
        () async {
      final now = DateTime.now();
      BleScanRecord hidden(String id) => BleScanRecord(
        id: id,
        name: '',
        rssi: -45,
        txPower: null,
        isConnectable: false,
        serviceUuids: const [],
        manufacturerData: const {},
        timestamp: now,
        isPayloadHidden: true,
      );
      bluetooth.records
        ..add(hidden('AA:00:00:00:00:21'))
        ..add(hidden('AA:00:00:00:00:22'))
        ..add(ble('AA:00:00:00:00:22', -45, name: 'Buds', at: now));
      await pumpEventQueue();
      // Updates to a listed device are published at most every 250 ms.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final apple = device('AA:00:00:00:00:21');
      expect(apple.deviceType, ScannedDeviceModel.appleHiddenType);
      expect(apple.manufacturer, 'Apple Inc.');
      expect(
        device('AA:00:00:00:00:22').deviceType,
        isNot(ScannedDeviceModel.appleHiddenType),
      );
    });

    test('paired / connected devices show their saved name', () async {
      bluetooth.known = {'AA:00:00:00:00:09': 'Invigilator Buds'};
      await vm().toggleScanning(false);
      await vm().toggleScanning(true);
      bluetooth.records.add(ble('AA:00:00:00:00:09', -70, at: DateTime.now()));
      await pumpEventQueue();

      expect(device('AA:00:00:00:00:09').displayName, 'Invigilator Buds');
      expect(device('AA:00:00:00:00:09').hasName, isTrue);
    });
  });

  group('baseline and trust', () {
    setUp(setUpContainer);

    test('takeBaseline trusts every known id of every transport', () async {
      final t = DateTime.now();
      const apple = {
        0x004C: [0x10, 0x05, 0x01],
      };
      bluetooth.records
        ..add(ble('AA:01', -50, at: t, manufacturerData: apple))
        ..add(ble('AA:02', -50, at: t, manufacturerData: apple));
      classicBt.records.add(classic('00:11:22:33:44:55', -60));
      wifiScan.scans.add([wifi('AndroidAP', 'AA:BB:CC:DD:EE:FF', -60)]);
      await pumpEventQueue();
      expect(read().groups.where((g) => g.isGrouped), hasLength(1));
      expect(read().hasBaseline, isFalse);

      final count = await vm().takeBaseline();

      const ids = {
        'AA:01',
        'AA:02',
        '00:11:22:33:44:55',
        'wifi:AA:BB:CC:DD:EE:FF',
      };
      expect(count, 4);
      expect(read().trustedIds, ids);
      expect(read().hasBaseline, isTrue);
      final session = container.read(sessionViewModelProvider)!;
      expect(session.trustedDeviceIds, ids);
      expect(session.hasBaseline, isTrue);
    });

    test(
      'trust and untrust act on the whole group; nearest sorts trusted last',
      () async {
        final t = DateTime.now();
        const apple = {
          0x004C: [0x10, 0x05, 0x01],
        };
        bluetooth.records
          ..add(ble('AA:01', -50, at: t, manufacturerData: apple))
          ..add(ble('AA:02', -50, at: t, manufacturerData: apple))
          ..add(
            ble(
              'BB:01',
              -70,
              name: 'Galaxy',
              at: t.subtract(const Duration(seconds: 1)),
            ),
          );
        await pumpEventQueue();
        expect(read().visibleGroups(DeviceFilter.all).first.id, 'AA:01');

        await vm().trustDevice('AA:02');
        expect(read().trustedIds, {'AA:01', 'AA:02'});
        // "Stable" never moves a card; "Nearest first" puts trusted last.
        expect(read().visibleGroups(DeviceFilter.all).map((g) => g.id), [
          'AA:01',
          'BB:01',
        ]);
        vm().setSortMode(ScanSortMode.nearest);
        expect(read().visibleGroups(DeviceFilter.all).map((g) => g.id), [
          'BB:01',
          'AA:01',
        ]);

        await vm().untrustDevice('AA:01');
        expect(read().trustedIds, isEmpty);
        expect(
          container.read(sessionViewModelProvider)!.trustedDeviceIds,
          isEmpty,
        );
      },
    );

    test('a rotated address of a trusted device stays trusted', () async {
      final tenSecondsAgo = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      bluetooth.records.add(
        ble('11:11', -60, name: 'AirPods Pro', at: tenSecondsAgo),
      );
      await pumpEventQueue();
      await vm().takeBaseline();

      await bleTwice('22:22', -55, name: 'AirPods Pro');

      expect(read().devices.map((d) => d.id), ['22:22']);
      expect(read().trustedIds, contains('22:22'));
      expect(read().alerts, isEmpty);
      await pumpEventQueue();
      expect(
        container.read(sessionViewModelProvider)!.trustedDeviceIds,
        contains('22:22'),
      );
    });

    test('without a session, baseline and trust are kept in memory', () async {
      await container
          .read(sessionViewModelProvider.notifier)
          .endCurrentSession();
      await pumpEventQueue();
      bluetooth.records.add(
        ble('11:11', -60, name: 'Desk', at: DateTime.now()),
      );
      await pumpEventQueue();

      expect(await vm().takeBaseline(), 1);
      expect(read().trustedIds, {'11:11'});
      expect(read().hasBaseline, isTrue);

      await bleTwice('33:33', -50, name: 'Intruder');
      expect(read().alerts.map((a) => a.deviceId), ['33:33']);
    });
  });

  group('alerts', () {
    setUp(setUpContainer);

    test('nothing is raised before the baseline', () async {
      await bleTwice('33:33', -50);
      classicBt.records.add(classic('00:11:22:33:44:55', -50));
      await pumpEventQueue();
      expect(read().alerts, isEmpty);
      expect(read().alertSeq, 0);
    });

    test('a close new BLE device heard over 3 s raises one alert', () async {
      await vm().takeBaseline();

      await bleTwice('33:33', -60, name: 'Galaxy S24');
      expect(read().alerts, hasLength(1));
      final alert = read().alerts.single;
      expect(alert.deviceId, '33:33');
      expect(alert.displayName, 'Galaxy S24');
      expect(alert.transport, DeviceTransport.ble);
      expect(alert.acknowledged, isFalse);
      expect(read().alertSeq, 1);
      expect(read().unacknowledgedAlertCount, 1);

      // Hearing it again never duplicates the alert.
      await bleTwice('33:33', -55, name: 'Galaxy S24');
      expect(read().alerts, hasLength(1));
      expect(read().alertSeq, 1);
    });

    test('BLE needs strength and a repeat over 3 s', () async {
      await vm().takeBaseline();

      await bleTwice('44:44', -85, name: 'Far phone');
      bluetooth.records.add(
        ble('55:55', -50, name: 'One packet', at: DateTime.now()),
      );
      await pumpEventQueue();
      await bleTwice(
        '66:66',
        -50,
        name: 'Quick',
        span: const Duration(seconds: 1),
      );

      expect(read().alerts, isEmpty);
    });

    test('trusted devices never alert; trusting removes an alert', () async {
      final t = DateTime.now();
      bluetooth.records.add(ble('11:11', -50, name: 'Desk', at: t));
      await pumpEventQueue();
      await vm().takeBaseline();
      bluetooth.records.add(
        ble('11:11', -50, name: 'Desk', at: t.add(const Duration(seconds: 5))),
      );
      await bleTwice('33:33', -50, name: 'Pocket');
      expect(read().alerts.map((a) => a.deviceId), ['33:33']);

      await vm().trustDevice('33:33');
      expect(read().alerts, isEmpty);
      expect(read().trustedIds, containsAll(['11:11', '33:33']));
    });

    test('classic needs one strong sighting; Wi-Fi only hotspots', () async {
      await vm().takeBaseline();

      classicBt.records
        ..add(classic('00:11:22:33:44:55', -70, deviceClass: 0x0404))
        ..add(classic('00:11:22:33:44:77', -90, deviceClass: 0x0404));
      wifiScan.scans.add([
        wifi('AndroidAP_1', 'AA:BB:CC:DD:EE:01', -78),
        wifi('AndroidAP_2', 'AA:BB:CC:DD:EE:02', -85),
        wifi('ExamHall', '00:11:22:33:44:66', -40),
      ]);
      await pumpEventQueue();

      expect(read().alerts.map((a) => a.deviceId).toSet(), {
        '00:11:22:33:44:55',
        'wifi:AA:BB:CC:DD:EE:01',
      });
      expect(read().alertSeq, 2);
    });

    test('another address of an alerted device does not alert again', () async {
      await vm().takeBaseline();
      const apple = {
        0x004C: [0x10, 0x05, 0x01],
      };
      await bleTwice('AA:01', -50, name: '', manufacturerData: apple);
      await bleTwice('AA:02', -50, name: '', manufacturerData: apple);

      expect(read().groups.where((g) => g.isGrouped), hasLength(1));
      expect(read().alerts, hasLength(1));
    });

    test('a device trusted before it appears never alerts', () async {
      await vm().takeBaseline();
      await vm().trustDevice('77:77');
      await bleTwice('77:77', -50, name: 'Invigilator phone');
      expect(read().alerts, isEmpty);
      expect(read().alertSeq, 0);
    });

    test('acknowledge one or all', () async {
      await vm().takeBaseline();
      await bleTwice('33:33', -50, name: 'A');
      await bleTwice('44:44', -50, name: 'B');
      expect(read().unacknowledgedAlertCount, 2);

      vm().acknowledgeAlert('33:33');
      expect(read().unacknowledgedAlertCount, 1);
      expect(read().alerts, hasLength(2));

      vm().acknowledgeAll();
      expect(read().unacknowledgedAlertCount, 0);
      expect(read().alerts.every((a) => a.acknowledged), isTrue);
    });
  });
}
