import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 17, 9);

ScannedDeviceModel dev(
  String id, {
  int rssi = -50,
  String name = '',
  String manufacturer = 'Apple Inc.',
  String type = 'Smartphone / Mobile',
  List<String> services = const [],
  Duration seenAfter = Duration.zero,
}) => ScannedDeviceModel(
  id: id,
  name: name,
  manufacturer: manufacturer,
  deviceType: type,
  rssi: rssi,
  serviceUuids: services,
  firstSeen: t0.add(seenAfter),
  lastSeen: t0.add(seenAfter),
);

List<List<String>> ids(List<ScannedDeviceGroup> groups) => [
  for (final g in groups) [for (final m in g.members) m.id],
];

void main() {
  group('groupLikelySameDevices', () {
    test('groups simultaneous nameless addresses with one fingerprint', () {
      final groups = groupLikelySameDevices([
        dev('A1', rssi: -49),
        dev('A2', rssi: -50, seenAfter: const Duration(seconds: 1)),
        dev('A3', rssi: -49, seenAfter: const Duration(seconds: 2)),
      ]);
      expect(ids(groups), [
        ['A1', 'A2', 'A3'],
      ]);
      expect(groups.single.isGrouped, isTrue);
      expect(groups.single.primary.id, 'A1');
    });

    test('never drops a device', () {
      final input = [
        dev('A1'),
        dev('A2'),
        dev('B1', manufacturer: 'Samsung'),
        dev('N1', name: 'AirPods Pro'),
      ];
      final members = groupLikelySameDevices(input)
          .expand((g) => g.members)
          .map((d) => d.id);
      expect(members.toSet(), input.map((d) => d.id).toSet());
      expect(members, hasLength(input.length));
    });

    test('does not group named devices', () {
      final groups = groupLikelySameDevices([
        dev('A1', name: 'iPhone'),
        dev('A2', name: 'iPhone'),
        dev('A3'),
      ]);
      expect(groups, hasLength(3));
    });

    test('does not group different vendors', () {
      expect(
        groupLikelySameDevices([
          dev('A1'),
          dev('S1', manufacturer: 'Samsung Electronics'),
        ]),
        hasLength(2),
      );
    });

    test('does not group unknown (generic) vendors', () {
      expect(
        groupLikelySameDevices([
          dev('G1', manufacturer: 'Generic BLE Hardware'),
          dev('G2', manufacturer: 'Generic BLE Hardware'),
        ]),
        hasLength(2),
      );
    });

    test('does not group different device types or services', () {
      expect(
        groupLikelySameDevices([dev('A1'), dev('A2', type: 'Audio Device')]),
        hasLength(2),
      );
      expect(
        groupLikelySameDevices([
          dev('A1', services: const ['180F']),
          dev('A2', services: const ['180F', '180A']),
        ]),
        hasLength(2),
      );
    });

    test('service UUID order and case do not matter', () {
      expect(
        groupLikelySameDevices([
          dev('A1', services: const ['180f', '180A']),
          dev('A2', services: const ['180a', '180F']),
        ]),
        hasLength(1),
      );
    });

    test('does not group signals far apart in strength', () {
      expect(
        groupLikelySameDevices([dev('A1', rssi: -45), dev('A2', rssi: -60)]),
        hasLength(2),
      );
      // 6 dB is still the same device.
      expect(
        groupLikelySameDevices([dev('A1', rssi: -50), dev('A2', rssi: -56)]),
        hasLength(1),
      );
    });

    test('does not group addresses that appeared far apart in time', () {
      expect(
        groupLikelySameDevices([
          dev('A1'),
          dev('A2', seenAfter: const Duration(seconds: 30)),
        ]),
        hasLength(2),
      );
    });

    test('a chain of near matches does not pull in a distant signal', () {
      // A1~A2 and A2~A3 are within 6 dB, but A1 and A3 are 10 dB apart.
      final groups = groupLikelySameDevices([
        dev('A1', rssi: -45),
        dev('A2', rssi: -50, seenAfter: const Duration(seconds: 1)),
        dev('A3', rssi: -55, seenAfter: const Duration(seconds: 2)),
      ]);
      expect(ids(groups), [
        ['A1', 'A2'],
        ['A3'],
      ]);
    });

    test('keeps the input order of group primaries', () {
      final groups = groupLikelySameDevices([
        dev('N1', name: 'Watch', seenAfter: const Duration(seconds: 20)),
        dev('A2', seenAfter: const Duration(seconds: 1)),
        dev('A1'),
      ]);
      expect(ids(groups), [
        ['N1'],
        ['A1', 'A2'],
      ]);
    });
  });

  group('filters use the group primary', () {
    test('a grouped smartphone matches the smartphone filter once', () {
      final state = ScannerState(devices: [dev('A1'), dev('A2')]);
      expect(state.visibleGroups(DeviceFilter.smartphones), hasLength(1));
      expect(state.visibleGroups(DeviceFilter.audioDevices), isEmpty);
      expect(
        state.emptyReason(DeviceFilter.audioDevices),
        ScannerEmptyReason.filteredOut,
      );
    });

    test('room boundary drops only the members outside it', () {
      final state = ScannerState(
        devices: [dev('A1', rssi: -84), dev('A2', rssi: -88)],
        isRoomBoundaryMode: true,
      );
      expect(state.groups.single.members, hasLength(2));
      expect(ids(state.activeGroups), [
        ['A1'],
      ]);
    });
  });
}
