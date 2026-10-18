import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/core/services/wifi/wifi_permission_gate.dart';
import 'package:exam_guard/core/services/wifi/wifi_scan_service_impl.dart';

class _FakeGate extends WifiPermissionGate {
  _FakeGate(this.onRequest);

  final bool Function() onRequest;
  int requests = 0;

  @override
  Future<bool> request(int sdkInt) async {
    requests++;
    return onRequest();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('exam_guard/wifi');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Map<String, Object?> status;
  late List<Map<String, Object?>> nativeResults;
  late int scans;
  late int cachedReads;

  setUp(() {
    status = {
      'sdkInt': 34,
      'wifiEnabled': true,
      'scanAlwaysAvailable': false,
      'locationEnabled': true,
      'hasPermission': true,
    };
    nativeResults = [
      {
        'ssid': '"Exam-Hotspot"',
        'bssid': 'aa:bb:cc:00:11:22',
        'level': -48,
        'frequency': 2437,
        'capabilities': '[WPA2-PSK-CCMP][ESS]',
      },
    ];
    scans = 0;
    cachedReads = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'status':
          return status;
        case 'scan':
          scans++;
          return {'started': true, 'results': nativeResults};
        case 'getScanResults':
          cachedReads++;
          return nativeResults;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  WifiScanServiceImpl build({_FakeGate? gate, bool isAndroid = true}) =>
      WifiScanServiceImpl(
        AppLogger(),
        isAndroid: isAndroid,
        permissions: gate ?? _FakeGate(() => true),
        pollInterval: const Duration(milliseconds: 20),
        scanInterval: const Duration(hours: 1),
      );

  Future<void> pump([int ms = 10]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  group('normalizeSsid', () {
    test('strips quotes, unknown and NUL padding', () {
      expect(normalizeSsid('"Home"'), 'Home');
      expect(normalizeSsid('Plain'), 'Plain');
      expect(normalizeSsid('<unknown ssid>'), '');
      expect(normalizeSsid('"<unknown ssid>"'), '');
      expect(normalizeSsid('\u0000\u0000'), '');
      expect(normalizeSsid(''), '');
      expect(normalizeSsid(null), '');
    });
  });

  test('parseWifiResults maps fields and skips entries without BSSID', () {
    final list = parseWifiResults([
      {
        'ssid': '',
        'bssid': '02:00:00:aa:bb:cc',
        'level': -70,
        'frequency': 5180,
        'capabilities': '[ESS]',
      },
      {'ssid': 'x', 'bssid': ''},
      'garbage',
    ]);
    expect(list, hasLength(1));
    expect(list.single.ssid, '');
    expect(list.single.bssid, '02:00:00:AA:BB:CC');
    expect(list.single.rssi, -70);
    expect(list.single.frequencyMhz, 5180);
    expect(list.single.capabilities, '[ESS]');
    expect(parseWifiResults(null), isEmpty);
  });

  test('emits normalized results and no problem', () async {
    final service = build();
    final first = service.results.first;
    await service.start('hotspots');
    final list = await first;
    expect(list.single.ssid, 'Exam-Hotspot');
    expect(list.single.bssid, 'AA:BB:CC:00:11:22');
    expect(await service.problem.first, isNull);
    await service.dispose();
  });

  test('respects the scan interval (throttle) across ticks', () async {
    final service = build();
    await service.start('a');
    await pump(120);
    expect(scans, 1);
    await service.stop('a');
    // A new session inside the window reads cached results instead.
    await service.start('a');
    expect(scans, 1);
    expect(cachedReads, 1);
    await service.dispose();
  });

  test('stops polling when the last owner leaves', () async {
    final service = build();
    await service.start('a');
    await service.start('b');
    await service.stop('a');
    await service.stop('b');
    await pump(30);
    var statusCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      statusCalls++;
      return null;
    });
    await pump(80);
    expect(statusCalls, 0);
    await service.dispose();
  });

  test('requests permission once and reports permissionDenied', () async {
    status['hasPermission'] = false;
    final gate = _FakeGate(() => false);
    final service = build(gate: gate);
    final problems = <WifiScanProblem?>[];
    final sub = service.problem.listen(problems.add);
    await service.start('a');
    await pump(80);
    expect(gate.requests, 1);
    expect(problems.first, isNull); // current value first
    expect(problems.last, WifiScanProblem.permissionDenied);
    expect(scans, 0);

    // Granted later (e.g. from Settings): recovers on the next poll.
    status['hasPermission'] = true;
    await pump(60);
    expect(problems.last, isNull);
    expect(scans, 1);
    await sub.cancel();
    await service.dispose();
  });

  test('granting from the request starts scanning right away', () async {
    status['hasPermission'] = false;
    final gate = _FakeGate(() {
      status['hasPermission'] = true;
      return true;
    });
    final service = build(gate: gate);
    final first = service.results.first;
    await service.start('a');
    expect((await first).single.ssid, 'Exam-Hotspot');
    await service.dispose();
  });

  test('locationOff on Android 12 and lower', () async {
    status['sdkInt'] = 31;
    status['locationEnabled'] = false;
    final service = build();
    await service.start('a');
    expect(await service.problem.first, WifiScanProblem.locationOff);
    expect(scans, 0);
    await service.dispose();
  });

  test('Android 13+ scans with Location off when results arrive', () async {
    status['locationEnabled'] = false;
    final service = build();
    await service.start('a');
    expect(await service.problem.first, isNull);
    expect(scans, 1);
    await service.dispose();
  });

  test('wifiOff only when scan-always-available is off too', () async {
    status['wifiEnabled'] = false;
    final service = build();
    await service.start('a');
    expect(await service.problem.first, WifiScanProblem.wifiOff);
    await service.stop('a');

    status['scanAlwaysAvailable'] = true;
    await service.start('a');
    expect(await service.problem.first, isNull);
    await service.dispose();
  });

  test('native permission error maps to permissionDenied', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') return status;
      throw PlatformException(code: 'permissionDenied');
    });
    final service = build();
    await service.start('a');
    expect(await service.problem.first, WifiScanProblem.permissionDenied);
    await service.dispose();
  });

  test('unsupported platform reports unsupported first', () async {
    final service = build(isAndroid: false);
    expect(service.isSupported, isFalse);
    await service.start('a');
    expect(await service.problem.first, WifiScanProblem.unsupported);
    expect(scans, 0);
    await service.dispose();
  });
}
