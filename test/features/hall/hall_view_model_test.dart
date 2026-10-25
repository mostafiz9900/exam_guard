// Two phones (and an ESP32 node) share one hall over real loopback sockets.

import 'package:exam_guard/core/services/local_link/i_local_link.dart';
import 'package:exam_guard/core/services/local_link/local_link_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/repository/hall_protocol.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/hall/view_model/node_alert_tracker.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

class _Loopback implements ILocalAddressLookup {
  @override
  Future<String?> localIpv4() async => '127.0.0.1';
}

class _FakeScanner extends ScannerViewModel {
  @override
  ScannerState build() => ScannerState(isScanning: true);

  void emit(ScannerState s) => state = s;
}

class _FakeSession extends SessionViewModel {
  _FakeSession(this.teacher);

  final String teacher;

  @override
  SessionModel? build() => SessionModel(
    id: 's',
    instituteName: 'School',
    teacherName: teacher,
    roomNumber: '12',
    startTime: DateTime(2026, 10, 25, 9),
  );

  void end() => state = state!.copyWith(endTime: DateTime(2026, 10, 25, 12));
}

ScannedDeviceModel _device(String id, int rssi, {String name = ''}) =>
    ScannedDeviceModel(
      id: id,
      name: name,
      deviceType: 'Smart Earpiece / Audio',
      rssi: rssi,
      lastSeen: DateTime.now(),
      firstSeen: DateTime.now(),
    );

/// Polls [condition] for up to 5 s (real sockets are involved).
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

class _Phone {
  _Phone(String teacher)
    : container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(_Storage()),
          localAddressLookupProvider.overrideWithValue(_Loopback()),
          scannerViewModelProvider.overrideWith(_FakeScanner.new),
          sessionViewModelProvider.overrideWith(() => _FakeSession(teacher)),
        ],
      ) {
    container.listen(hallViewModelProvider, (_, _) {});
  }

  final ProviderContainer container;

  HallState get state => container.read(hallViewModelProvider);
  HallViewModel get vm => container.read(hallViewModelProvider.notifier);
  _FakeScanner get scanner =>
      container.read(scannerViewModelProvider.notifier) as _FakeScanner;
  _FakeSession get session =>
      container.read(sessionViewModelProvider.notifier) as _FakeSession;

  Future<void> dispose() async {
    await vm.leave();
    container.dispose();
  }
}

void main() {
  late _Phone host;
  late _Phone member;

  setUp(() {
    host = _Phone('Host Teacher');
    member = _Phone('Second Teacher');
  });

  tearDown(() async {
    await member.dispose();
    await host.dispose();
  });

  Future<void> hostAndJoin() async {
    await host.vm.host();
    expect(host.state.status, HallLinkStatus.hosting);
    await member.vm.join(host.state.invite!.encode());
    await _until(() => member.state.status == HallLinkStatus.connected);
    await _until(() => host.state.members.length == 2);
  }

  test('a phone joins by invite; both see both members', () async {
    await hostAndJoin();
    expect(member.state.room, '12');
    expect(member.state.members.map((m) => m.name), [
      'Host Teacher',
      'Second Teacher',
    ]);
    expect(member.state.members.first.isHost, isTrue);
  });

  test('sightings flow both ways, tagged with who heard them', () async {
    await hostAndJoin();
    member.scanner.emit(
      ScannerState(devices: [_device('AA:01', -55, name: 'Buds')]),
    );
    host.scanner.emit(ScannerState(devices: [_device('BB:01', -70)]));
    member.vm.publishSightingsNow();
    host.vm.publishSightingsNow();

    await _until(() => host.state.remoteDevices.isNotEmpty);
    final atHost = host.state.remoteDevices.single;
    expect(atHost.device.id, 'AA:01');
    expect(atHost.sourceName, 'Second Teacher');

    await _until(() => member.state.remoteDevices.isNotEmpty);
    expect(member.state.remoteDevices.single.device.id, 'BB:01');
    expect(member.state.remoteDevices.single.sourceName, 'Host Teacher');
  });

  test('far devices are not shared', () async {
    await hostAndJoin();
    member.scanner.emit(
      ScannerState(devices: [_device('AA:01', -60), _device('AA:02', -95)]),
    );
    member.vm.publishSightingsNow();
    await _until(() => host.state.remoteDevices.isNotEmpty);
    expect(host.state.remoteDevices.map((d) => d.device.id), ['AA:01']);
  });

  test('a new-device alert reaches the other phone once', () async {
    await hostAndJoin();
    final alert = NewDeviceAlert(
      deviceId: 'AA:09',
      displayName: 'Earpiece',
      deviceType: 'Smart Earpiece / Audio',
      transport: DeviceTransport.ble,
      rssi: -58,
      detectedAt: DateTime.now(),
    );
    member.scanner.emit(ScannerState(alerts: [alert]));
    member.scanner.emit(ScannerState(alerts: [alert], alertSeq: 1));

    await _until(() => host.state.remoteAlerts.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(host.state.remoteAlerts, hasLength(1));
    expect(host.state.pendingAlerts.single.sourceName, 'Second Teacher');

    host.vm.acknowledgeAllRemoteAlerts();
    expect(host.state.pendingAlerts, isEmpty);
  });

  test('a wrong token is refused', () async {
    await host.vm.host();
    final bad = HallInvite(
      host: '127.0.0.1',
      port: host.state.invite!.port,
      token: 'WRONG',
      room: '12',
    );
    await member.vm.join(bad.encode());
    await _until(() => member.state.status == HallLinkStatus.failed);
    expect(member.state.errorKey, 'hall_err_rejected');
    expect(host.state.members, hasLength(1));
  });

  test('a garbage code is refused before connecting', () async {
    await member.vm.join('hello');
    expect(member.state.isActive, isFalse);
    expect(member.state.errorKey, 'hall_err_bad_code');
  });

  test('an ESP32 node joins with the node key and shares sightings', () async {
    await host.vm.host();
    final node = LocalLinkClientImpl(AppLogger());
    addTearDown(node.disconnect);
    await node.connect(
      host.state.invite!.socketUri,
      HallProtocol.encodeHello(
        const HallMember(
          id: 'N-1',
          name: 'ExamGuard-Node-01',
          kind: HallMemberKind.node,
        ),
        host.state.nodeKey,
      ),
    );
    await _until(() => host.state.nodeCount == 1);

    node.send(HallProtocol.encodeSightings('spoofed', [_device('CC:01', -50)]));
    await _until(() => host.state.remoteDevices.isNotEmpty);
    final d = host.state.remoteDevices.single;
    // The hub says who sent it, not the message.
    expect(d.sourceId, 'N-1');
    expect(d.sourceName, 'ExamGuard-Node-01');
  });

  test('firmware-shaped node sightings arrive classified', () async {
    await host.vm.host();
    final node = LocalLinkClientImpl(AppLogger());
    addTearDown(node.disconnect);
    // Exactly what firmware/esp32/src/main.cpp sends.
    await node.connect(host.state.invite!.socketUri, {
      't': 'hello',
      'v': 1,
      'token': host.state.nodeKey,
      'member': {'id': 'N-A1B2C3', 'name': 'ExamGuard-Node-01', 'kind': 'node'},
    });
    await _until(() => host.state.nodeCount == 1);
    node.send({
      't': 'sightings',
      'v': 1,
      'from': 'N-A1B2C3',
      'items': [
        {
          'id': 'AA:00:00:00:00:01',
          'rssi': -48,
          'tx': 'ble',
          'mfid': 76,
          'mfb': 7,
        },
        {
          'id': 'wifi:AA:00:00:00:00:02',
          'rssi': -55,
          'tx': 'wifi',
          'name': 'AndroidAP_77',
        },
      ],
    });
    await _until(() => host.state.remoteDevices.length == 2);
    final byId = {for (final r in host.state.remoteDevices) r.device.id: r};
    expect(
      byId['AA:00:00:00:00:01']!.device.displayName,
      startsWith('AirPods'),
    );
    expect(
      byId['wifi:AA:00:00:00:00:02']!.device.deviceType,
      contains('Hotspot'),
    );
    expect(byId.values.first.sourceName, 'ExamGuard-Node-01');
  });

  Future<LocalLinkClientImpl> joinNode(String id, String name) async {
    final node = LocalLinkClientImpl(AppLogger());
    addTearDown(node.disconnect);
    await node.connect(host.state.invite!.socketUri, {
      't': 'hello',
      'v': 1,
      'token': host.state.nodeKey,
      'member': {'id': id, 'name': name, 'kind': 'node'},
    });
    return node;
  }

  Map<String, Object?> earpiece(String id, int rssi) => {
    't': 'sightings',
    'v': 1,
    'items': [
      {'id': id, 'rssi': rssi, 'tx': 'ble', 'name': 'TWS Earbud'},
    ],
  };

  test(
    'a node that goes away is flagged on every phone, cleared on return',
    () async {
      await hostAndJoin();
      final node = await joinNode('N-7', 'ExamGuard-Node-Back');
      await _until(() => member.state.nodeCount == 1);
      expect(host.state.offlineNodes, isEmpty);

      await node.disconnect();
      await _until(() => host.state.offlineNodes.isNotEmpty);
      await _until(() => member.state.offlineNodes.isNotEmpty);
      expect(
        member.state.offlineNodes.single.member.name,
        'ExamGuard-Node-Back',
      );

      await joinNode('N-7', 'ExamGuard-Node-Back');
      await _until(() => host.state.offlineNodes.isEmpty);
      await _until(() => member.state.offlineNodes.isEmpty);
    },
  );

  test('dismissing an offline node stops the warning', () async {
    await host.vm.host();
    final node = await joinNode('N-8', 'Node');
    await _until(() => host.state.nodeCount == 1);
    await node.disconnect();
    await _until(() => host.state.offlineNodes.isNotEmpty);
    host.vm.dismissOfflineNode('N-8');
    expect(host.state.offlineNodes, isEmpty);
  });

  test(
    'after the baseline, a new device near a node alerts every phone',
    () async {
      await hostAndJoin();
      final node = await joinNode('N-9', 'ExamGuard-Node-Front');
      await _until(() => host.state.nodeCount == 1);
      // Room baseline on the host.
      host.scanner.emit(
        ScannerState(
          baselineAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );

      node.send(earpiece('EE:00:00:00:00:01', -55));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(host.state.remoteAlerts, isEmpty, reason: 'needs 3 s');
      await Future<void>.delayed(NodeAlertTracker.confirmSpan);
      node.send(earpiece('EE:00:00:00:00:01', -55));

      await _until(() => host.state.pendingAlerts.isNotEmpty);
      await _until(() => member.state.pendingAlerts.isNotEmpty);
      final a = member.state.pendingAlerts.single;
      expect(a.sourceName, 'ExamGuard-Node-Front');
      expect(a.alert.deviceType, contains('Audio'));
    },
  );

  test('a node with the wrong key is refused', () async {
    await host.vm.host();
    final node = LocalLinkClientImpl(AppLogger());
    addTearDown(node.disconnect);
    final reply = node.messages.first.timeout(const Duration(seconds: 5));
    await node.connect(
      host.state.invite!.socketUri,
      HallProtocol.encodeHello(
        const HallMember(id: 'N-2', name: 'Node', kind: HallMemberKind.node),
        'WRONGKEY',
      ),
    );
    expect(HallProtocol.typeOf(await reply), HallProtocol.reject);
    expect(host.state.nodeCount, 0);
  });

  test('a member leaving takes its devices with it', () async {
    await hostAndJoin();
    member.scanner.emit(ScannerState(devices: [_device('AA:01', -55)]));
    member.vm.publishSightingsNow();
    await _until(() => host.state.remoteDevices.isNotEmpty);

    await member.vm.leave();
    await _until(() => host.state.members.length == 1);
    expect(host.state.remoteDevices, isEmpty);
  });

  test('ending the exam closes the hall', () async {
    await host.vm.host();
    host.session.end();
    await _until(() => !host.state.isActive);
    expect(host.state.status, HallLinkStatus.idle);
  });

  test('cannot host or join without a running exam', () async {
    host.session.end();
    await pumpEventQueue();
    await host.vm.host();
    expect(host.state.isActive, isFalse);
    expect(host.state.errorKey, 'hall_err_no_exam');
  });
}
