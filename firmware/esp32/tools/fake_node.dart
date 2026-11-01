// A pretend Pahara sensor node, for trying the app without an ESP32.
//
// It joins a hosted hall exactly like the firmware (same hello, same
// sightings every 2 s) and "hears" a few devices, one of them an earpiece
// that switches on after 20 s so a new-device alert can be seen.
//
// 1. Phone: start an exam → Dashboard → Hall link → Host this hall.
// 2. Computer on the same Wi-Fi / the phone's hotspot:
//      dart run firmware/esp32/tools/fake_node.dart <phone-ip> <node-key>
//    (phone ip: shown under the QR code; node key: Sensor nodes screen).
//    Hall map: run it three times with different names and ids, e.g.
//      ... <ip> <key> Pahara-Front 01
//      ... <ip> <key> Pahara-Back-left 02
//      ... <ip> <key> Pahara-Back-right 03
//    then place them on Hall map; each "hears" the earpiece differently.
// 3. The Sensor nodes card on the dashboard turns green. Stop this script
//    (Ctrl+C) and the card shows "Sensor node offline".
//
// Not part of the app; uses only the Dart SDK.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run fake_node.dart <phone-ip> <node-key> [name] [id]',
    );
    exit(64);
  }
  final host = args[0];
  final key = args[1];
  final name = args.length > 2 ? args[2] : 'Pahara-Fake-Node';
  final suffix = args.length > 3 ? args[3] : '01';
  final id = 'N-FAKE$suffix';
  // Each pretend node is a different distance from the earpiece:
  // id 01 closest (-52 dBm), 02 at -58, 03 at -64, 04 at -70.
  final earBase = -52 - 6 * (((int.tryParse(suffix) ?? 1) - 1) % 4);
  final started = DateTime.now();
  final random = Random();

  final socket = await WebSocket.connect('ws://$host:47800/');
  stdout.writeln('connected to $host, saying hello as $name');
  socket.add(
    jsonEncode({
      't': 'hello',
      'v': 1,
      'token': key,
      'member': {'id': id, 'name': name, 'kind': 'node'},
    }),
  );

  Timer? timer;
  socket.listen(
    (data) {
      final msg = jsonDecode(data as String) as Map<String, Object?>;
      switch (msg['t']) {
        case 'welcome':
          stdout.writeln('joined room ${msg['room']} — sending every 2 s');
          timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
            int rssi(int base) => base + random.nextInt(7) - 3;
            final earpieceOn =
                DateTime.now().difference(started) > const Duration(seconds: 20);
            socket.add(
              jsonEncode({
                't': 'sightings',
                'v': 1,
                'from': id,
                'items': [
                  {
                    'id': 'wifi:AA:BB:CC:00:00:01',
                    'name': 'Hall-Router',
                    'rssi': rssi(-55),
                    'tx': 'wifi',
                  },
                  {
                    'id': 'C0:FF:EE:00:00:02',
                    'name': 'Mi Smart Band 8',
                    'rssi': rssi(-70),
                    'tx': 'ble',
                  },
                  if (earpieceOn)
                    {
                      'id': 'C0:FF:EE:00:00:03',
                      'name': 'Mini Earbud',
                      'rssi': rssi(earBase),
                      'tx': 'ble',
                    },
                ],
              }),
            );
          });
        case 'reject':
          stderr.writeln('rejected (${msg['reason']}): wrong node key?');
          exit(1);
      }
    },
    onDone: () {
      timer?.cancel();
      stdout.writeln('hall closed');
      exit(0);
    },
  );
}
