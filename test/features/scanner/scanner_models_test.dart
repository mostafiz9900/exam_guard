import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 10, 18, 9);

ScannedDeviceModel _d(String id, int rssi, {String name = ''}) =>
    ScannedDeviceModel(
      id: id,
      name: name,
      rssi: rssi,
      lastSeen: _t,
      firstSeen: _t,
    );

NewDeviceAlert _alert({
  String id = 'AA',
  DateTime? at,
  bool acknowledged = false,
  String name = 'Phone',
  int rssi = -60,
}) => NewDeviceAlert(
  deviceId: id,
  displayName: name,
  deviceType: 'Smartphone',
  transport: DeviceTransport.ble,
  rssi: rssi,
  detectedAt: at ?? _t,
  acknowledged: acknowledged,
);

void main() {
  group('ScannedDeviceGroup', () {
    test('a single member is its own primary and not grouped', () {
      final group = ScannedDeviceGroup([_d('A', -70)]);
      expect(group.primary.id, 'A');
      expect(group.id, 'A');
      expect(group.isGrouped, isFalse);
      expect(group.others, isEmpty);
      expect(group.strongestRssi, -70);
    });

    test('several members: first is primary, others follow in order', () {
      final group = ScannedDeviceGroup([
        _d('A', -80),
        _d('B', -55),
        _d('C', -90),
      ]);
      expect(group.primary.id, 'A');
      expect(group.id, 'A');
      expect(group.isGrouped, isTrue);
      expect(group.others.map((m) => m.id), ['B', 'C']);
      expect(group.strongestRssi, -55);
    });

    test('strongest RSSI may come from the primary', () {
      final group = ScannedDeviceGroup([_d('A', -40), _d('B', -60)]);
      expect(group.strongestRssi, -40);
    });

    test('equality compares member ids in order only', () {
      final a = ScannedDeviceGroup([_d('A', -40), _d('B', -60)]);
      final sameIdsOtherData = ScannedDeviceGroup([
        _d('A', -90, name: 'x'),
        _d('B', -10),
      ]);
      expect(a, sameIdsOtherData);
      expect(a.hashCode, sameIdsOtherData.hashCode);
      expect(a, equals(a));

      expect(a, isNot(ScannedDeviceGroup([_d('B', -60), _d('A', -40)])));
      expect(a, isNot(ScannedDeviceGroup([_d('A', -40)])));
      expect(
        a,
        isNot(ScannedDeviceGroup([_d('A', -40), _d('B', -60), _d('C', -1)])),
      );
      expect(a, isNot(ScannedDeviceGroup([_d('A', -40), _d('Z', -60)])));
      // ignore: unrelated_type_equality_checks
      expect(a == 'A', isFalse);
    });

    test('toString lists member ids', () {
      expect(
        ScannedDeviceGroup([_d('A', -1), _d('B', -2)]).toString(),
        'ScannedDeviceGroup(A, B)',
      );
    });

    test('an empty member list is rejected in debug', () {
      expect(() => ScannedDeviceGroup(const []), throwsAssertionError);
    });
  });

  group('NewDeviceAlert', () {
    test('defaults to not acknowledged', () {
      expect(_alert().acknowledged, isFalse);
    });

    test('copyWith acknowledged keeps every other field', () {
      final alert = _alert(name: 'iPhone', rssi: -48);
      final acked = alert.copyWith(acknowledged: true);
      expect(acked.acknowledged, isTrue);
      expect(acked.deviceId, alert.deviceId);
      expect(acked.displayName, 'iPhone');
      expect(acked.deviceType, 'Smartphone');
      expect(acked.transport, DeviceTransport.ble);
      expect(acked.rssi, -48);
      expect(acked.detectedAt, _t);
    });

    test('copyWith without arguments keeps the acknowledged flag', () {
      expect(_alert(acknowledged: true).copyWith().acknowledged, isTrue);
      expect(_alert().copyWith().acknowledged, isFalse);
      expect(_alert().copyWith(), _alert());
    });

    test('equality uses id, detection time and acknowledged', () {
      final a = _alert();
      expect(a, _alert(name: 'Other name', rssi: -99));
      expect(a.hashCode, _alert(name: 'Other name', rssi: -99).hashCode);
      expect(a, equals(a));
      expect(a, isNot(_alert(id: 'BB')));
      expect(a, isNot(_alert(at: _t.add(const Duration(seconds: 1)))));
      expect(a, isNot(_alert(acknowledged: true)));
      // ignore: unrelated_type_equality_checks
      expect(a == 'AA', isFalse);
    });

    test('toString shows the acknowledged flag only when set', () {
      expect(
        _alert().toString(),
        'NewDeviceAlert(AA, Phone, DeviceTransport.ble, -60 dBm)',
      );
      expect(
        _alert(acknowledged: true).toString(),
        'NewDeviceAlert(AA, Phone, DeviceTransport.ble, -60 dBm, '
        'acknowledged)',
      );
    });
  });
}
