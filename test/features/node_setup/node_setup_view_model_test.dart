// Bluetooth setup of an ESP32 node, end to end against a fake node that
// answers like the firmware.

import 'dart:convert';

import 'package:exam_guard/core/services/bluetooth/i_ble_gatt.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/model/node_setup_protocol.dart';
import 'package:exam_guard/features/node_setup/view_model/node_setup_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'node_fakes.dart';

void main() {
  group('protocol', () {
    test('setup nodes are recognised by name or service', () {
      expect(NodeSetupProtocol.isSetupNode('Pahara-Setup-A1B2C3', []), true);
      expect(
        NodeSetupProtocol.isSetupNode('', [
          NodeSetupProtocol.service.toUpperCase(),
        ]),
        true,
      );
      expect(NodeSetupProtocol.isSetupNode('Pahara-Node-A1', []), false);
      expect(NodeSetupProtocol.isSetupNode('AirPods', ['180F']), false);
      expect(
        NodeSetupProtocol.nodeIdFromName('Pahara-Setup-A1B2C3'),
        'N-A1B2C3',
      );
      expect(NodeSetupProtocol.nodeIdFromName('Pahara-Setup-'), isNull);
    });

    test('config carries version, Wi-Fi, key, name and hub', () {
      final j = jsonDecode(
        utf8.decode(
          NodeSetupProtocol.encodeConfig(
            const NodeSetupConfig(
              ssid: 'Hall',
              password: 'secret123',
              nodeKey: 'KEY',
              name: 'Back row',
            ),
          ),
        ),
      );
      expect(j, {
        'v': 1,
        'ssid': 'Hall',
        'pass': 'secret123',
        'key': 'KEY',
        'name': 'Back row',
        'hub': '',
      });
    });

    test('info, networks and status decode; junk is ignored', () {
      List<int> b(String s) => utf8.encode(s);
      final info = NodeSetupProtocol.decodeInfo(
        b(
          '{"v":1,"id":"N-1","name":"Pahara-Node-1","fw":"1.1.0","key":true,"ssid":"Hall"}',
        ),
      )!;
      expect(info.id, 'N-1');
      expect(info.hasKey, isTrue);
      expect(info.savedSsid, 'Hall');
      expect(NodeSetupProtocol.decodeInfo(b('{"v":1}')), isNull);
      expect(NodeSetupProtocol.decodeInfo(b('not json')), isNull);

      final nets = NodeSetupProtocol.decodeNetworks(
        b('[{"s":"A","r":-40},{"s":"B","r":-60,"o":1},{"s":""},{"x":1}]'),
      );
      expect(nets.map((n) => n.ssid), ['A', 'B']);
      expect(nets[1].isOpen, isTrue);
      expect(NodeSetupProtocol.decodeNetworks(b('{}')), isEmpty);

      final s = NodeSetupProtocol.decodeStatus(
        b('{"s":"bad_password","d":"A"}'),
      )!;
      expect(s.status, NodeSetupStatus.badPassword);
      expect(s.status.isFailure, isTrue);
      expect(s.detail, 'A');
      expect(
        NodeSetupProtocol.decodeStatus(b('{"s":"from_the_future"}'))!.status,
        NodeSetupStatus.unknown,
      );
    });
  });

  group('view model', () {
    late FakeBle ble;
    late FakeNodeLink node;
    late FakeGatt gatt;
    late FakeStorage storage;
    late ProviderContainer c;

    NodeSetupState read() => c.read(nodeSetupViewModelProvider);
    NodeSetupViewModel vm() => c.read(nodeSetupViewModelProvider.notifier);

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
      }
    }

    setUp(() {
      ble = FakeBle();
      node = FakeNodeLink();
      gatt = FakeGatt(node);
      storage = FakeStorage();
      c = ProviderContainer(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(ble),
          bleGattProvider.overrideWithValue(gatt),
          localStorageProvider.overrideWithValue(storage),
          hallViewModelProvider.overrideWith(FakeHall.new),
        ],
      );
      addTearDown(c.dispose);
      c.listen(nodeSetupViewModelProvider, (_, _) {});
    });

    Future<void> findAndPick() async {
      vm().startSearch();
      await settle();
      ble.hear('BB:01', 'Pahara-Setup-A1B2C3', -50);
      await settle();
      await vm().select(read().candidates.first);
      await settle();
    }

    test(
      'search lists only setup nodes, strongest first, while open',
      () async {
        vm().startSearch();
        await settle();
        expect(ble.owners, contains('node_setup'));
        ble
          ..hear('AA:01', 'AirPods', -40)
          ..hear('BB:01', 'Pahara-Setup-A1B2C3', -70)
          ..hear('BB:02', '', -45, services: [NodeSetupProtocol.service])
          ..hear('BB:02', 'Pahara-Setup-D4E5F6', -46);
        await settle();
        expect(read().candidates.map((x) => x.deviceId), ['BB:02', 'BB:01']);
        expect(read().candidates.first.code, 'D4E5F6');

        await vm().select(read().candidates.first);
        await settle();
        expect(ble.owners, isEmpty, reason: 'scan stops once connecting');
      },
    );

    test('connecting reads the node and its Wi-Fi list', () async {
      await storage.write('node_setup_last_ssid', 'Staff-WiFi');
      await findAndPick();
      expect(read().step, NodeSetupStep.wifi);
      expect(read().info!.id, 'N-A1B2C3');
      expect(read().networks.map((n) => n.ssid), [
        'Hall-Hotspot',
        'Staff-WiFi',
        'Cafe',
      ]);
      expect(read().suggestedSsid, 'Staff-WiFi', reason: 'used last time');
    });

    test('a failed connection goes back to searching with a reason', () async {
      gatt.fail = true;
      await findAndPick();
      expect(read().step, NodeSetupStep.search);
      expect(read().errorKey, 'node_err_connect');
      expect(read().isConnecting, isFalse);
    });

    test('password rules: required, 8+ chars, none for open Wi-Fi', () async {
      await findAndPick();
      expect(vm().validate(ssid: '', password: 'x'), 'node_err_ssid_required');
      expect(
        vm().validate(ssid: 'Hall-Hotspot', password: ''),
        'node_err_password_required',
      );
      expect(
        vm().validate(ssid: 'Hall-Hotspot', password: 'short'),
        'node_err_password_short',
      );
      expect(vm().validate(ssid: 'Cafe', password: ''), isNull);
      vm().submit(ssid: 'Hall-Hotspot', password: 'short');
      expect(read().step, NodeSetupStep.wifi);
      expect(node.configs, isEmpty, reason: 'nothing sent');
    });

    test('success: the app sends its node key, follows the node, remembers '
        'the hotspot (not the password)', () async {
      await findAndPick();
      vm().submit(
        ssid: 'Hall-Hotspot',
        password: 'hall12345',
        name: ' Back-row ',
      );
      expect(read().step, NodeSetupStep.applying);
      await settle();

      expect(node.configs.single, {
        'v': 1,
        'ssid': 'Hall-Hotspot',
        'pass': 'hall12345',
        'key': 'K7M2Q9XW3D',
        'name': 'Back-row',
        'hub': '',
      });
      expect(read().step, NodeSetupStep.done);
      expect(read().progress, [
        NodeSetupStatus.joining,
        NodeSetupStatus.wifiOk,
        NodeSetupStatus.hostOk,
        NodeSetupStatus.saved,
      ]);
      expect(read().hostReachable, isTrue);
      expect(read().savedName, 'Pahara-Back-row');
      expect(storage.values['node_setup_last_ssid'], 'Hall-Hotspot');
      expect(storage.values.values, isNot(contains('hall12345')));
      expect(read().errorKey, isNull, reason: 'restart is expected');
    });

    test('hall not hosted yet is a note, not a failure', () async {
      node.outcome = NodeOutcome.noHost;
      await findAndPick();
      vm().submit(ssid: 'Hall-Hotspot', password: 'hall12345');
      await settle();
      expect(read().step, NodeSetupStep.done);
      expect(read().hostReachable, isFalse);
    });

    test('wrong password: stays connected, fix and retry', () async {
      node.outcome = NodeOutcome.badPassword;
      await findAndPick();
      vm().submit(ssid: 'Hall-Hotspot', password: 'wrongpass');
      await settle();
      expect(read().step, NodeSetupStep.applying);
      expect(read().failure, NodeSetupStatus.badPassword);
      expect(read().failedSsid, 'Hall-Hotspot');

      vm().editWifi();
      expect(read().step, NodeSetupStep.wifi);
      expect(read().failure, isNull);
      node.outcome = NodeOutcome.ok;
      vm().submit(ssid: 'Hall-Hotspot', password: 'hall12345');
      await settle();
      expect(read().step, NodeSetupStep.done);
      expect(node.configs, hasLength(2));
    });

    test('the node leaving setup mid-way says so', () async {
      node.outcome = NodeOutcome.dropBeforeSave;
      await findAndPick();
      vm().submit(ssid: 'Hall-Hotspot', password: 'hall12345');
      await settle();
      expect(read().step, NodeSetupStep.prepare);
      expect(read().errorKey, 'node_err_lost');
    });

    test('rescan asks the node and updates the list', () async {
      await findAndPick();
      node.networks = const [('New-Hotspot', -40, false)];
      await vm().rescanNetworks();
      expect(read().isRescanning, isFalse);
      expect(read().networks.map((n) => n.ssid), ['New-Hotspot']);
    });

    test(
      'the next node gets the same hotspot and password, not the name',
      () async {
        await findAndPick();
        vm().submit(ssid: 'Staff-WiFi', password: 'hall12345', name: 'Front');
        await settle();
        vm().addAnother();
        expect(read().draft!.ssid, 'Staff-WiFi');
        expect(read().draft!.password, 'hall12345');
        expect(read().draft!.name, isEmpty);
        gatt.node = node = FakeNodeLink(id: 'N-D4E5F6');
        await findAndPick();
        expect(read().suggestedSsid, 'Staff-WiFi');
      },
    );

    test('add another starts over and lets go of the node', () async {
      await findAndPick();
      vm().addAnother();
      await settle();
      expect(read().step, NodeSetupStep.prepare);
      expect(read().info, isNull);
      expect(node.closed, isTrue);
    });

    test('Bluetooth off is reported while searching', () async {
      vm().startSearch();
      await settle();
      ble.adapter.add(BleAdapterStatus.off);
      await settle();
      expect(read().bluetoothOff, isTrue);
    });

    test('disposing closes the link', () async {
      await findAndPick();
      c.dispose();
      expect(node.closed, isTrue);
      // Recreate so tearDown's dispose has something valid.
      c = ProviderContainer(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(ble),
          bleGattProvider.overrideWithValue(gatt),
          localStorageProvider.overrideWithValue(storage),
        ],
      );
    });

    test('a gatt error type is what the core throws', () {
      expect(const BleGattException('x').toString(), contains('x'));
    });
  });
}
