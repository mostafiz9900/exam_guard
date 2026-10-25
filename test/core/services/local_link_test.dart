// Real loopback sockets: hub accepts/rejects hellos, relays, notices
// leaving peers; client reports its state.

import 'dart:async';

import 'package:exam_guard/core/services/local_link/i_local_link.dart';
import 'package:exam_guard/core/services/local_link/local_link_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _next<T>(Stream<T> s) => s.first.timeout(const Duration(seconds: 5));

void main() {
  late LocalLinkHubImpl hub;
  late int port;
  final clients = <LocalLinkClientImpl>[];

  LocalLinkClientImpl client() {
    final c = LocalLinkClientImpl(AppLogger());
    clients.add(c);
    return c;
  }

  Uri uri() => Uri.parse('ws://127.0.0.1:$port');

  setUp(() async {
    hub = LocalLinkHubImpl(AppLogger());
    port = await hub.start(
      port: 0,
      accept: (hello) => hello['token'] == 'OK' ? hello['id']! as String : null,
      rejectReply: (_) => {'t': 'reject'},
    );
  });

  tearDown(() async {
    for (final c in clients) {
      await c.disconnect();
    }
    clients.clear();
    await hub.stop();
  });

  test('accepted peer joins, messages reach the hub, hub replies', () async {
    final joined = _next(hub.peers);
    final a = client();
    final replies = <Map<String, Object?>>[];
    final sub = a.messages.listen(replies.add);
    await a.connect(uri(), {'token': 'OK', 'id': 'A'});
    final e = await joined;
    expect(e.joined, isTrue);
    expect(e.peerId, 'A');

    final msg = _next(hub.messages);
    a.send({'t': 'ping', 'n': 1});
    final got = await msg;
    expect(got.peerId, 'A');
    expect(got.json['n'], 1);

    hub.sendTo('A', {'t': 'pong'});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(replies.single['t'], 'pong');
    await sub.cancel();
  });

  test('broadcast skips the excepted peer', () async {
    final a = client();
    final b = client();
    final joins = hub.peers.take(2).toList();
    await a.connect(uri(), {'token': 'OK', 'id': 'A'});
    await b.connect(uri(), {'token': 'OK', 'id': 'B'});
    await joins.timeout(const Duration(seconds: 5));

    final toB = _next(b.messages);
    final aGot = <Map<String, Object?>>[];
    final sub = a.messages.listen(aGot.add);
    hub.broadcast({'t': 'x'}, except: 'A');
    expect((await toB)['t'], 'x');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(aGot, isEmpty);
    await sub.cancel();
  });

  test('a wrong token is rejected and closed', () async {
    final c = client();
    final reply = _next(c.messages);
    final closed = c.state
        .firstWhere((s) => s == LinkClientState.disconnected)
        .timeout(const Duration(seconds: 5));
    await c.connect(uri(), {'token': 'NO', 'id': 'X'});
    expect((await reply)['t'], 'reject');
    await closed;
  });

  test('a peer that leaves is reported', () async {
    final c = client();
    final events = hub.peers.take(2).toList();
    await c.connect(uri(), {'token': 'OK', 'id': 'A'});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await c.disconnect();
    final e = await events.timeout(const Duration(seconds: 5));
    expect(e.map((x) => x.joined), [true, false]);
  });

  test('connecting to nothing throws and stays disconnected', () async {
    await hub.stop();
    final c = client();
    await expectLater(
      c.connect(uri(), {'token': 'OK', 'id': 'A'}),
      throwsA(anything),
    );
    expect(await _next(c.state), LinkClientState.disconnected);
  });
}
