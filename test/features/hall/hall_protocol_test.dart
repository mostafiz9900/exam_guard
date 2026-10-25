// Hall link protocol: invites, message round-trips, tolerant decoding.

import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/repository/hall_protocol.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HallInvite', () {
    test('round-trips through the QR text', () {
      const invite = HallInvite(
        host: '192.168.43.1',
        port: 47800,
        token: 'ABCD2345',
        room: '12/B',
      );
      final parsed = HallInvite.parse(invite.encode())!;
      expect(parsed.host, '192.168.43.1');
      expect(parsed.port, 47800);
      expect(parsed.token, 'ABCD2345');
      expect(parsed.room, '12/B');
      expect(parsed.socketUri.toString(), 'ws://192.168.43.1:47800');
    });

    test('rejects anything else', () {
      for (final text in [
        '',
        'https://example.com',
        'examguard://join?h=1.2.3.4&p=0&t=X',
        'examguard://join?h=1.2.3.4&p=47800',
        'examguard://other?h=1.2.3.4&p=47800&t=X',
      ]) {
        expect(HallInvite.parse(text), isNull, reason: text);
      }
    });
  });

  test('members round-trip; malformed entries are skipped', () {
    const m = HallMember(
      id: 'P-1',
      name: 'Rahim',
      kind: HallMemberKind.node,
      isHost: false,
    );
    final json = HallProtocol.encodeMembers([m]);
    (json['members']! as List).add({'name': 'no id'});
    expect(HallProtocol.decodeMembers(json), [m]);
  });

  test('sightings round-trip with transport, tx power and names', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1760000000000);
    final d = ScannedDeviceModel(
      id: 'AA:BB',
      name: 'Buds',
      manufacturer: 'Anker',
      deviceType: 'Smart Earpiece / Audio',
      rssi: -61,
      txPower: 4,
      lastSeen: at,
      firstSeen: at,
    );
    final json = HallProtocol.encodeSightings('P-1', [d]);
    expect(HallProtocol.typeOf(json), HallProtocol.sightings);
    expect(HallProtocol.fromOf(json), 'P-1');
    final back = HallProtocol.decodeSightings(json).single;
    expect(back.id, 'AA:BB');
    expect(back.name, 'Buds');
    expect(back.rssi, -61);
    expect(back.txPower, 4);
    expect(back.deviceType, 'Smart Earpiece / Audio');
    expect(back.transport, DeviceTransport.ble);
    expect(back.lastSeen, at);
  });

  test('nameless devices travel without a made-up name', () {
    final d = ScannedDeviceModel(
      id: 'AA:CC',
      name: '',
      rssi: -70,
      lastSeen: DateTime.now(),
      firstSeen: DateTime.now(),
    );
    final back = HallProtocol.decodeSightings(
      HallProtocol.encodeSightings('P-1', [d]),
    ).single;
    expect(back.hasName, isFalse);
  });

  test('bad sighting items are dropped, not fatal', () {
    final list = HallProtocol.decodeSightings({
      't': 'sightings',
      'items': [
        'junk',
        {'id': 'X'},
        {'id': 'OK', 'rssi': -50, 'tx': 'wifi'},
      ],
    });
    expect(list.single.id, 'OK');
    expect(list.single.transport, DeviceTransport.wifi);
  });

  test('raw node sightings are classified with the phone rules', () {
    final list = HallProtocol.decodeSightings({
      't': 'sightings',
      'items': [
        // AirPods proximity pairing: Apple company id, type 0x07.
        {
          'id': 'AA:00:00:00:00:01',
          'rssi': -55,
          'tx': 'ble',
          'mfid': 0x004C,
          'mfb': 0x07,
        },
        {
          'id': 'AA:00:00:00:00:02',
          'name': 'soundcore R50i',
          'rssi': -60,
          'tx': 'ble',
        },
        {
          'id': 'wifi:AA:00:00:00:00:03',
          'name': 'AndroidAP_1234',
          'rssi': -50,
          'tx': 'wifi',
        },
      ],
    });
    expect(list[0].manufacturer, 'Apple Inc.');
    expect(list[0].deviceType, contains('Audio'));
    expect(list[0].displayName, startsWith('AirPods'));
    expect(list[1].deviceType, contains('Audio'));
    expect(list[2].deviceType, contains('Hotspot'));
  });

  test('alerts round-trip', () {
    final a = NewDeviceAlert(
      deviceId: 'AA:BB',
      displayName: 'Buds',
      deviceType: 'Smart Earpiece / Audio',
      transport: DeviceTransport.classic,
      rssi: -58,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );
    final back = HallProtocol.decodeAlert(HallProtocol.encodeAlert('P-2', a))!;
    expect(back.deviceId, a.deviceId);
    expect(back.transport, DeviceTransport.classic);
    expect(back.detectedAt, a.detectedAt);
    expect(HallProtocol.decodeAlert({'alert': 'x'}), isNull);
  });
}
