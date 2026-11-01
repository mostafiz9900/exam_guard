// Fakes for the ESP32 Bluetooth setup: a BLE radio that "hears" nodes in
// setup mode, and a node that behaves like firmware/esp32/src/main.cpp.

import 'dart:async';
import 'dart:convert';

import 'package:exam_guard/core/services/bluetooth/i_ble_gatt.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/model/node_setup_protocol.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

class FakeStorage implements ILocalStorage {
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

class FakeBle implements IBluetoothService {
  final records = StreamController<BleScanRecord>.broadcast();
  final adapter = StreamController<BleAdapterStatus>.broadcast();
  final Set<String> owners = {};

  void hear(String id, String name, int rssi, {List<String>? services}) =>
      records.add(
        BleScanRecord(
          id: id,
          name: name,
          rssi: rssi,
          txPower: null,
          isConnectable: true,
          serviceUuids: services ?? const [],
          manufacturerData: const {},
          timestamp: DateTime.now(),
        ),
      );

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Stream<BleAdapterStatus> adapterStatus() async* {
    yield BleAdapterStatus.on;
    yield* adapter.stream;
  }

  @override
  Future<void> startScan(String owner) async => owners.add(owner);

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// How the fake node's Wi-Fi test ends.
enum NodeOutcome { ok, noHost, badPassword, noNetwork, dropBeforeSave }

/// A node in setup mode. Mirrors the firmware: status notifications
/// joining → wifi_ok → host_ok|no_host → saved, then it disconnects.
class FakeNodeLink implements BleGattLink {
  FakeNodeLink({
    this.id = 'N-A1B2C3',
    this.networks = const [
      ('Hall-Hotspot', -48, false),
      ('Staff-WiFi', -70, false),
      ('Cafe', -80, true),
    ],
  });

  final String id;

  /// What the node "sees"; change it to simulate a rescan.
  List<(String, int, bool)> networks;
  NodeOutcome outcome = NodeOutcome.ok;

  /// Every config the app wrote, decoded.
  final List<Map<String, Object?>> configs = [];
  final _status = StreamController<List<int>>.broadcast();
  final _done = Completer<void>();
  bool closed = false;

  List<int> _json(Object o) => utf8.encode(jsonEncode(o));

  void _notify(String s, [String? d]) => _status.add(_json({'s': s, 'd': ?d}));

  /// The node switched off / left setup.
  void drop() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<List<int>> read(String service, String characteristic) async {
    if (closed) throw const BleGattException('closed');
    return switch (characteristic) {
      NodeSetupProtocol.info => _json({
        'v': 1,
        'id': id,
        'name': 'Pahara-Node-${id.substring(2)}',
        'fw': '1.1.0',
        'key': false,
      }),
      NodeSetupProtocol.networks => _json([
        for (final (s, r, open) in networks) {'s': s, 'r': r, if (open) 'o': 1},
      ]),
      _ => throw BleGattException('no $characteristic'),
    };
  }

  @override
  Future<void> write(
    String service,
    String characteristic,
    List<int> value,
  ) async {
    final j = jsonDecode(utf8.decode(value)) as Map<String, Object?>;
    if (j['cmd'] == 'scan') {
      scheduleMicrotask(() {
        _notify('scanning');
        _notify('ready');
      });
      return;
    }
    configs.add(j);
    final ssid = j['ssid']! as String;
    final name = (j['name'] as String?)?.isNotEmpty == true
        ? 'Pahara-${j['name']}'
        : 'Pahara-Node-${id.substring(2)}';
    Future<void>(() async {
      _notify('joining', ssid);
      await Future<void>.delayed(Duration.zero);
      switch (outcome) {
        case NodeOutcome.badPassword:
          _notify('bad_password', ssid);
          return;
        case NodeOutcome.noNetwork:
          _notify('no_network', ssid);
          return;
        case NodeOutcome.dropBeforeSave:
          _notify('wifi_ok', '192.168.43.20');
          drop();
          return;
        case NodeOutcome.ok || NodeOutcome.noHost:
          _notify('wifi_ok', '192.168.43.20');
          _notify(outcome == NodeOutcome.ok ? 'host_ok' : 'no_host');
          _notify('saved', name);
          await Future<void>.delayed(Duration.zero);
          drop(); // restarts
      }
    });
  }

  @override
  Stream<List<int>> notifications(String service, String characteristic) =>
      _status.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    closed = true;
    drop();
  }
}

class FakeGatt implements IBleGatt {
  FakeGatt(this.node);

  FakeNodeLink node;
  bool fail = false;
  final List<String> opened = [];

  @override
  Future<BleGattLink> open(
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    opened.add(deviceId);
    if (fail) throw const BleGattException('timeout');
    return node;
  }
}

class FakeHall extends HallViewModel {
  FakeHall([
    this.initial = const HallState(selfId: 'P-ME', nodeKey: 'K7M2Q9XW3D'),
  ]);

  final HallState initial;
  int hostCalls = 0;

  @override
  HallState build() => initial;

  void set(HallState s) => state = s;

  @override
  Future<void> host() async => hostCalls++;
}

class FakeSession extends SessionViewModel {
  FakeSession({this.running = true});

  final bool running;

  @override
  SessionModel? build() => running
      ? SessionModel(
          id: 's',
          instituteName: 'School',
          teacherName: 'Teacher',
          roomNumber: '302-B',
          startTime: DateTime(2026, 11, 1, 9),
        )
      : null;
}

const hostingWithNode = HallState(
  selfId: 'P-ME',
  nodeKey: 'K7M2Q9XW3D',
  role: HallRole.host,
  status: HallLinkStatus.hosting,
  members: [
    HallMember(id: 'P-ME', name: 'Teacher', kind: HallMemberKind.phone),
    HallMember(
      id: 'N-A1B2C3',
      name: 'Pahara-Back-row',
      kind: HallMemberKind.node,
    ),
  ],
);
