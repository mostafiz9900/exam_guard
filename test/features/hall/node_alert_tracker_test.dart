// Node alerts follow the phone scanner's rules and don't cry wolf.

import 'package:exam_guard/features/hall/view_model/node_alert_tracker.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 25, 9);

ScannedDeviceModel _ble(
  String id,
  int rssi, {
  String name = '',
  String mfr = 'Apple Inc.',
  String type = 'Smart Earpiece / Audio',
}) => ScannedDeviceModel(
  id: id,
  name: name,
  manufacturer: mfr,
  deviceType: type,
  rssi: rssi,
  lastSeen: _t0,
  firstSeen: _t0,
);

void main() {
  late NodeAlertTracker tracker;
  final baseline = _t0.add(const Duration(minutes: 1));
  Set<String> trusted = {};

  List<NewDeviceAlert> feed(
    List<ScannedDeviceModel> devices,
    Duration at, {
    DateTime? baselineAt,
    String node = 'N-1',
  }) => tracker.onSightings(
    nodeId: node,
    devices: devices,
    now: _t0.add(at),
    baselineAt: baselineAt,
    isTrusted: trusted.contains,
  );

  setUp(() {
    tracker = NodeAlertTracker();
    trusted = {};
  });

  test('no alerts before a baseline exists', () {
    expect(feed([_ble('A', -50)], Duration.zero), isEmpty);
    expect(feed([_ble('A', -50)], const Duration(seconds: 10)), isEmpty);
  });

  test('devices heard before the baseline are part of the room', () {
    feed([_ble('A', -50)], Duration.zero);
    expect(
      feed([_ble('A', -50)], const Duration(minutes: 2), baselineAt: baseline),
      isEmpty,
    );
  });

  test('a new close device heard over 3 s raises exactly one alert', () {
    final d = _ble('NEW', -60);
    expect(
      feed([d], const Duration(minutes: 2), baselineAt: baseline),
      isEmpty,
    );
    final alerts = feed(
      [d],
      const Duration(minutes: 2, seconds: 4),
      baselineAt: baseline,
    );
    expect(alerts.single.deviceId, 'NEW');
    expect(
      feed([d], const Duration(minutes: 2, seconds: 8), baselineAt: baseline),
      isEmpty,
    );
  });

  test('one stray packet or a far device is not an alert', () {
    expect(
      feed(
        [_ble('FAR', -85)],
        const Duration(minutes: 2),
        baselineAt: baseline,
      ),
      isEmpty,
    );
    expect(
      feed(
        [_ble('FAR', -85)],
        const Duration(minutes: 2, seconds: 5),
        baselineAt: baseline,
      ),
      isEmpty,
    );
  });

  test('trusted devices and other ExamGuard nodes never alert', () {
    trusted = {'T'};
    final node = _ble('N2', -50, name: 'ExamGuard-Node-02', mfr: 'Espressif');
    for (final s in [120, 125]) {
      expect(
        feed(
          [_ble('T', -50), node],
          Duration(seconds: s),
          baselineAt: baseline,
        ),
        isEmpty,
      );
    }
  });

  test('a known device that changed its random address is not new', () {
    feed([_ble('OLD', -55)], Duration.zero);
    // OLD goes silent; 20 s later the same kind of device appears with a
    // new address, after the baseline.
    for (final s in [80, 85, 90]) {
      expect(
        feed(
          [_ble('ROTATED', -56)],
          Duration(seconds: s),
          baselineAt: baseline,
        ),
        isEmpty,
      );
    }
  });

  test('a different kind of device is still new', () {
    feed([_ble('OLD', -55)], Duration.zero);
    final other = _ble(
      'ESP',
      -55,
      mfr: 'Espressif',
      type: 'Covert Microcontroller / ESP32',
    );
    feed([other], const Duration(seconds: 80), baselineAt: baseline);
    final alerts = feed(
      [other],
      const Duration(seconds: 85),
      baselineAt: baseline,
    );
    expect(alerts.single.deviceId, 'ESP');
  });

  test('Wi-Fi: only phone hotspots, at once', () {
    ScannedDeviceModel wifi(String type) => ScannedDeviceModel(
      id: 'wifi:$type',
      name: 'x',
      manufacturer: 'Wi-Fi',
      deviceType: type,
      rssi: -60,
      lastSeen: _t0,
      firstSeen: _t0,
      transport: DeviceTransport.wifi,
    );
    final alerts = feed(
      [wifi(WirelessClassifier.hotspotType), wifi('Wi-Fi Access Point')],
      const Duration(minutes: 2),
      baselineAt: baseline,
    );
    expect(alerts.single.deviceId, 'wifi:${WirelessClassifier.hotspotType}');
  });

  test('nodes are tracked separately', () {
    feed([_ble('A', -50)], Duration.zero, node: 'N-1');
    feed(
      [_ble('A', -50)],
      const Duration(minutes: 2),
      baselineAt: baseline,
      node: 'N-2',
    );
    final alerts = feed(
      [_ble('A', -50)],
      const Duration(minutes: 2, seconds: 4),
      baselineAt: baseline,
      node: 'N-2',
    );
    // N-1 knew it before the baseline, but N-2 meets it only now.
    expect(alerts.single.deviceId, 'A');
  });
}
