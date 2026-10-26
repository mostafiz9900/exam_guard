// Scanner list stability: stable order, nearest-first throttle/hysteresis,
// sticky grouping, stale → evicted, smoothing, "Near me" and selection.

import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';
import 'package:exam_guard/features/scanner/view_model/list_order.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/scanner/view_model/signal_smoothing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Bluetooth implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();

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
  Future<void> startScan(String owner) async {}

  @override
  Future<void> stopScan(String owner) async {}

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      const BleConnectionInfo();

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {}
}

class _Classic implements IClassicBluetoothService {
  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  final records = StreamController<ClassicBtRecord>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<ClassicBtRecord> get discoveries => records.stream;

  @override
  Future<void> start(String owner) async {}

  @override
  Future<void> stop(String owner) async {}

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

final t0 = DateTime(2026, 10, 18, 9);

ScannedDeviceModel dev(
  String id, {
  int rssi = -50,
  String name = '',
  Duration firstSeenAt = Duration.zero,
  Duration lastSeenAt = Duration.zero,
}) => ScannedDeviceModel(
  id: id,
  name: name,
  manufacturer: 'Apple Inc.',
  deviceType: 'Smartphone / Mobile',
  rssi: rssi,
  firstSeen: t0.add(firstSeenAt),
  lastSeen: t0.add(lastSeenAt),
);

List<List<String>> ids(List<ScannedDeviceGroup> groups) => [
  for (final g in [...groups]..sort((a, b) => a.id.compareTo(b.id)))
    [for (final m in g.members) m.id],
];

void main() {
  group('RssiSmoother and ProximityBand', () {
    test('EMA with alpha 0.3; first sample taken as is', () {
      final s = RssiSmoother();
      expect(s.add('A', -70), -70);
      expect(s.add('A', -50), closeTo(-64, 0.001));
      expect(s.add('A', -50), closeTo(-59.8, 0.001));
      expect(s.valueOf('B'), isNull);
    });

    test('band changes only 3 dB past a boundary', () {
      var band = ProximityBand.next(null, -66);
      expect(band, ProximityBand.near);
      // Hovering around -65 keeps "near".
      for (final rssi in [-64, -66, -63, -65, -64]) {
        band = ProximityBand.next(band, rssi);
        expect(band, ProximityBand.near, reason: '$rssi dBm');
      }
      band = ProximityBand.next(band, -61);
      expect(band, ProximityBand.veryClose);
      // …and back only once clearly below.
      band = ProximityBand.next(band, -67);
      expect(band, ProximityBand.veryClose);
      band = ProximityBand.next(band, -69);
      expect(band, ProximityBand.near);
    });
  });

  group('NearestOrder', () {
    NearestEntry e(String k, double rssi, {bool trusted = false}) =>
        (key: k, rssi: rssi, trusted: trusted);

    test('first sort is a full sort, trusted last', () {
      final o = NearestOrder();
      expect(
        o.order([e('A', -80), e('B', -50, trusted: true), e('C', -60)], t0),
        ['C', 'A', 'B'],
      );
    });

    test('re-sorts at most every 3 s; new entries are appended', () {
      final o = NearestOrder()..order([e('A', -60), e('B', -70)], t0);
      // B is much stronger now, but 2 s have passed: keep the order.
      final t2 = t0.add(const Duration(seconds: 2));
      expect(o.order([e('A', -60), e('B', -40), e('C', -30)], t2), [
        'A',
        'B',
        'C',
      ]);
      final t3 = t0.add(const Duration(seconds: 3));
      expect(o.order([e('A', -60), e('B', -40), e('C', -30)], t3), [
        'C',
        'B',
        'A',
      ]);
    });

    test('swaps only when the difference is more than 4 dB', () {
      final o = NearestOrder()..order([e('A', -60), e('B', -70)], t0);
      final t3 = t0.add(const Duration(seconds: 3));
      expect(o.order([e('A', -60), e('B', -57)], t3), ['A', 'B']);
      final t6 = t0.add(const Duration(seconds: 6));
      expect(o.order([e('A', -60), e('B', -55.5)], t6), ['B', 'A']);
    });

    test('removed entries drop out without reordering the rest', () {
      final o = NearestOrder()
        ..order([e('A', -50), e('B', -60), e('C', -70)], t0);
      expect(
        o.order([e('A', -50), e('C', -40)], t0.add(const Duration(seconds: 1))),
        ['A', 'C'],
      );
    });
  });

  group('StickyDeviceGrouper', () {
    bool never(ScannedDeviceModel _) => false;

    test('drifting past 6 dB does not split a group', () {
      final g = StickyDeviceGrouper();
      expect(
        ids(
          g.group(
            [dev('A1', rssi: -50), dev('A2', rssi: -52)],
            now: t0,
            isSilent: never,
          ),
        ),
        [
          ['A1', 'A2'],
        ],
      );
      // 10 dB apart: the plain rule would split them; sticky keeps them.
      final later = t0.add(const Duration(seconds: 20));
      expect(
        ids(
          g.group(
            [dev('A1', rssi: -50), dev('A2', rssi: -60)],
            now: later,
            isSilent: never,
          ),
        ),
        [
          ['A1', 'A2'],
        ],
      );
    });

    test('splits after more than 12 dB apart for 10 s', () {
      final g = StickyDeviceGrouper()
        ..group(
          [dev('A1', rssi: -50), dev('A2', rssi: -50)],
          now: t0,
          isSilent: never,
        );
      final far = [dev('A1', rssi: -45), dev('A2', rssi: -65)];
      final t20 = t0.add(const Duration(seconds: 20));
      expect(ids(g.group(far, now: t20, isSilent: never)), hasLength(1));
      final t25 = t0.add(const Duration(seconds: 25));
      expect(ids(g.group(far, now: t25, isSilent: never)), hasLength(1));
      // Coming back within 12 dB resets the timer.
      final t28 = t0.add(const Duration(seconds: 28));
      g.group(
        [dev('A1', rssi: -50), dev('A2', rssi: -55)],
        now: t28,
        isSilent: never,
      );
      final t35 = t0.add(const Duration(seconds: 35));
      expect(ids(g.group(far, now: t35, isSilent: never)), hasLength(1));
      final t45 = t0.add(const Duration(seconds: 45));
      expect(ids(g.group(far, now: t45, isSilent: never)), [
        ['A1'],
        ['A2'],
      ]);
    });

    test('splits when one member goes silent', () {
      final g = StickyDeviceGrouper()
        ..group([dev('A1'), dev('A2')], now: t0, isSilent: never);
      final t20 = t0.add(const Duration(seconds: 20));
      expect(
        ids(
          g.group(
            [dev('A1'), dev('A2')],
            now: t20,
            isSilent: (d) => d.id == 'A2',
          ),
        ),
        [
          ['A1'],
          ['A2'],
        ],
      );
    });

    test('new members still need the strict rule to join', () {
      final g = StickyDeviceGrouper()
        ..group(
          [dev('A1', rssi: -50), dev('A2', rssi: -52)],
          now: t0,
          isSilent: never,
        );
      final t2 = t0.add(const Duration(seconds: 2));
      final groups = g.group(
        [
          dev('A1', rssi: -50),
          dev('A2', rssi: -52),
          // 9 dB from A1: not within the 6 dB window.
          dev('A3', rssi: -59, firstSeenAt: const Duration(seconds: 2)),
        ],
        now: t2,
        isSilent: never,
      );
      expect(ids(groups), [
        ['A1', 'A2'],
        ['A3'],
      ]);
    });

    test('established groups never merge', () {
      final g = StickyDeviceGrouper();
      final t30 = t0.add(const Duration(seconds: 30));
      // Far apart at first: two groups.
      g.group(
        [dev('A1', rssi: -40), dev('A2', rssi: -70)],
        now: t0,
        isSilent: never,
      );
      expect(
        ids(
          g.group(
            [dev('A1', rssi: -50), dev('A2', rssi: -51)],
            now: t30,
            isSilent: never,
          ),
        ),
        [
          ['A1'],
          ['A2'],
        ],
      );
    });
  });

  group('Near me filter', () {
    test('smoothed RSSI ≥ -62 dBm and still being heard', () {
      final state = ScannerState(
        devices: [
          dev('N1', name: 'Close', rssi: -60),
          dev('N2', name: 'Edge', rssi: -62),
          dev('N3', name: 'Far', rssi: -63),
          dev('N4', name: 'Quiet', rssi: -50),
        ],
        staleIds: const {'N4'},
      );
      expect(
        state.visibleGroups(DeviceFilter.nearMe).map((g) => g.id).toSet(),
        {'N1', 'N2'},
      );
    });
  });

  group('view model', () {
    late _Bluetooth bluetooth;
    late _Classic classic;
    late ProviderContainer container;
    late DateTime now;

    ScannerState read() => container.read(scannerViewModelProvider);
    ScannerViewModel vm() => container.read(scannerViewModelProvider.notifier);
    List<String> order() => [for (final g in read().groups) g.id];

    BleScanRecord ble(String id, int rssi, {String? name}) => BleScanRecord(
      id: id,
      name: name ?? 'Phone $id',
      rssi: rssi,
      txPower: null,
      isConnectable: true,
      serviceUuids: const [],
      manufacturerData: const {},
      timestamp: now,
    );

    Future<void> hear(String id, int rssi, {String? name}) async {
      bluetooth.records.add(ble(id, rssi, name: name));
      await pumpEventQueue();
    }

    /// Lets the coalesced publish (≤ 250 ms) happen.
    Future<void> publishWindow() =>
        Future<void>.delayed(const Duration(milliseconds: 300));

    setUp(() async {
      now = t0;
      bluetooth = _Bluetooth();
      classic = _Classic();
      container = ProviderContainer(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(bluetooth),
          permissionServiceProvider.overrideWithValue(_Permissions()),
          classicBluetoothServiceProvider.overrideWithValue(classic),
          scannerClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(scannerViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    test('a device that keeps disappearing is flagged as toggling', () async {
      await hear('T', -60);
      await hear('S', -60);
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 40));
        await hear('T', -60);
        await hear('S', -60);
      }
      await publishWindow();
      // S was heard just as often, but both reappeared: same pattern means
      // both toggle. A steady device must not be flagged.
      expect(read().togglingIds, containsAll(['T', 'S']));
      final h = vm().historyOf('T')!;
      expect(h.reappearances, hasLength(3));
      expect(h.intervals, hasLength(4));
    });

    test('a steadily heard device is never toggling', () async {
      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(seconds: 10));
        await hear('S', -60);
      }
      await publishWindow();
      expect(read().togglingIds, isEmpty);
      expect(vm().historyOf('S')!.intervals, hasLength(1));
    });

    test('stable order: new devices are appended at the bottom', () async {
      await hear('A', -80);
      await hear('B', -50);
      await hear('C', -40);
      expect(order(), ['A', 'B', 'C']);

      // A gets much stronger: nothing moves.
      for (var i = 0; i < 5; i++) {
        await hear('A', -35);
      }
      await publishWindow();
      expect(order(), ['A', 'B', 'C']);
      expect(read().devices.firstWhere((d) => d.id == 'A').rssi, -43);

      now = now.add(const Duration(seconds: 1));
      await hear('D', -30);
      expect(order(), ['A', 'B', 'C', 'D']);
    });

    test('value updates are coalesced, new devices show at once', () async {
      await hear('A', -70);
      expect(read().devices.single.rssi, -70);
      await hear('A', -50);
      expect(read().devices.single.rssi, -70, reason: 'not yet published');
      await publishWindow();
      expect(read().devices.single.rssi, -64, reason: 'EMA, alpha 0.3');
    });

    test('nearest first: full sort on switch, then ≤ every 3 s', () async {
      await hear('A', -80);
      await hear('B', -60);
      vm().setSortMode(ScanSortMode.nearest);
      expect(read().sortMode, ScanSortMode.nearest);
      expect(order(), ['B', 'A']);

      now = now.add(const Duration(seconds: 1));
      await hear('C', -40);
      expect(order(), ['B', 'A', 'C'], reason: 'appended until next sort');

      now = now.add(const Duration(seconds: 3));
      await hear('C', -40);
      await publishWindow();
      expect(order(), ['C', 'B', 'A']);

      vm().setSortMode(ScanSortMode.stable);
      expect(order(), ['A', 'B', 'C']);
    });

    test('a quiet device is muted, then removed after 30 s', () async {
      await hear('A', -60);
      await hear('B', -60);
      expect(read().staleIds, isEmpty);

      now = now.add(const Duration(seconds: 16));
      await hear('B', -60);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(read().staleIds, {'A'});
      expect(order(), ['A', 'B'], reason: 'kept in place while quiet');
      expect(read().secondsSinceSeen(read().groups.first.primary), 16);

      // Heard again: back to normal in its old place.
      await hear('A', -60);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(read().staleIds, isEmpty);
      expect(order(), ['A', 'B']);

      now = now.add(const Duration(seconds: 31));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(read().devices, isEmpty);
    });

    group('selection', () {
      test('at most 5 BLE devices; the limit is explained', () async {
        for (var i = 1; i <= 6; i++) {
          await hear('0$i', -50);
        }
        vm().startSelection('01');
        for (var i = 2; i <= 6; i++) {
          vm().toggleSelected('0$i');
        }
        expect(read().isSelecting, isTrue);
        expect(read().selectedIds, {'01', '02', '03', '04', '05'});
        expect(read().noticeKey, 'scan_select_limit');
        expect(read().noticeArgs, {'max': '5'});
        expect(read().selectedDevices.map((d) => d.id), [
          '01',
          '02',
          '03',
          '04',
          '05',
        ]);

        vm().toggleSelected('02');
        expect(read().selectedIds, hasLength(4));

        vm().cancelSelection();
        expect(read().isSelecting, isFalse);
        expect(read().selectedIds, isEmpty);
      });

      test('classic devices cannot be picked', () async {
        classic.records.add(
          ClassicBtRecord(
            address: '00:11:22:33:44:55',
            name: 'Nano Ear',
            rssi: -60,
            majorDeviceClass: 0x0400,
            deviceClass: 0x0404,
            timestamp: now,
          ),
        );
        await pumpEventQueue();
        vm().startSelection('00:11:22:33:44:55');
        expect(read().selectedIds, isEmpty);
        expect(read().noticeKey, 'scan_select_ble_only');
      });

      test(
        'strongest untrusted: top 3 BLE, trusted and quiet skipped',
        () async {
          await hear('A', -70);
          await hear('B', -50);
          await hear('C', -60);
          await hear('D', -40);
          await hear('E', -45);
          await vm().trustDevice('D');
          now = now.add(const Duration(seconds: 16));
          for (final id in ['A', 'B', 'C', 'D']) {
            await hear(id, id == 'A' ? -70 : (id == 'B' ? -50 : -60));
          }
          await publishWindow();
          expect(read().staleIds, {'E'});
          expect(vm().strongestUntrustedTargets().map((d) => d.id), [
            'B',
            'C',
            'A',
          ]);
        },
      );

      test('nothing to walk to raises a notice', () async {
        expect(vm().strongestUntrustedTargets(), isEmpty);
        expect(read().noticeKey, 'scan_walk_none');
      });
    });

    test('seat sweep is offered for BLE devices, with or without a layout', () {
      final ble = dev('A');
      expect(ScannerState().canSeatSweep(ble), isTrue);
      expect(ScannerState(hasSeatLayout: true).canSeatSweep(ble), isTrue);
      expect(
        ScannerState(hasSeatLayout: true)
            .canSeatSweep(ble.copyWith(transport: DeviceTransport.classic)),
        isFalse,
      );
    });
  });
}
