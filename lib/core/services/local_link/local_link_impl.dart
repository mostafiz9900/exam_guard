import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exam_guard/core/services/local_link/i_local_link.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// Dead connections are noticed within about two ping intervals.
const Duration _pingInterval = Duration(seconds: 5);

/// A peer that never says hello is dropped.
const Duration _helloTimeout = Duration(seconds: 10);

Map<String, Object?>? _decode(Object? data) {
  if (data is! String) return null;
  try {
    final value = jsonDecode(data);
    return value is Map<String, Object?> ? value : null;
  } on FormatException {
    return null;
  }
}

/// [ILocalLinkHub] on a `dart:io` HTTP server upgraded to WebSockets.
class LocalLinkHubImpl implements ILocalLinkHub {
  LocalLinkHubImpl(this._logger);

  final AppLogger _logger;
  HttpServer? _server;
  final Map<String, WebSocket> _sockets = {};
  final _messages = StreamController<LinkMessage>.broadcast();
  final _peers = StreamController<LinkPeerEvent>.broadcast();

  @override
  Stream<LinkMessage> get messages => _messages.stream;

  @override
  Stream<LinkPeerEvent> get peers => _peers.stream;

  @override
  bool get isRunning => _server != null;

  @override
  Future<int> start({
    required int port,
    required LinkAcceptor accept,
    required Map<String, Object?> Function(Map<String, Object?> hello)
    rejectReply,
  }) async {
    await stop();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(
      (request) => _onRequest(request, accept, rejectReply),
      onError: (Object e, StackTrace st) =>
          _logger.warning('Hall hub server error', e, st),
    );
    return server.port;
  }

  Future<void> _onRequest(
    HttpRequest request,
    LinkAcceptor accept,
    Map<String, Object?> Function(Map<String, Object?>) rejectReply,
  ) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      // Plain GET: lets a node or a browser check the hub is reachable.
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ExamGuard hall hub')
        ..close();
      return;
    }
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } catch (e, st) {
      _logger.warning('Hall hub upgrade failed', e, st);
      return;
    }
    socket.pingInterval = _pingInterval;

    String? peerId;
    final helloTimer = Timer(_helloTimeout, () {
      if (peerId == null) socket.close(WebSocketStatus.policyViolation);
    });
    socket.listen(
      (data) {
        final json = _decode(data);
        if (json == null) return;
        final id = peerId;
        if (id != null) {
          _messages.add(LinkMessage(id, json));
          return;
        }
        helloTimer.cancel();
        final accepted = accept(json);
        if (accepted == null) {
          socket
            ..add(jsonEncode(rejectReply(json)))
            ..close(WebSocketStatus.policyViolation);
          return;
        }
        // A rejoining peer replaces its old connection.
        _sockets.remove(accepted)?.close(WebSocketStatus.goingAway);
        peerId = accepted;
        _sockets[accepted] = socket;
        _peers.add(LinkPeerEvent.joined(accepted, json));
      },
      onDone: () {
        helloTimer.cancel();
        final id = peerId;
        if (id != null && identical(_sockets[id], socket)) {
          _sockets.remove(id);
          _peers.add(LinkPeerEvent.left(id));
        }
      },
      onError: (Object e, StackTrace st) =>
          _logger.warning('Hall peer connection error', e, st),
      cancelOnError: true,
    );
  }

  @override
  void sendTo(String peerId, Map<String, Object?> json) {
    _sockets[peerId]?.add(jsonEncode(json));
  }

  @override
  void broadcast(Map<String, Object?> json, {String? except}) {
    final text = jsonEncode(json);
    for (final entry in _sockets.entries) {
      if (entry.key != except) entry.value.add(text);
    }
  }

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    final sockets = _sockets.values.toList();
    _sockets.clear();
    for (final s in sockets) {
      await s.close(WebSocketStatus.goingAway);
    }
    await server?.close(force: true);
  }
}

/// [ILocalLinkClient] on a `dart:io` WebSocket.
class LocalLinkClientImpl implements ILocalLinkClient {
  LocalLinkClientImpl(this._logger);

  static const Duration _connectTimeout = Duration(seconds: 8);

  final AppLogger _logger;
  WebSocket? _socket;
  final _messages = StreamController<Map<String, Object?>>.broadcast();
  final _states = StreamController<LinkClientState>.broadcast();
  LinkClientState _state = LinkClientState.disconnected;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  Stream<LinkClientState> get state async* {
    yield _state;
    yield* _states.stream;
  }

  void _set(LinkClientState s) {
    if (_state == s) return;
    _state = s;
    _states.add(s);
  }

  @override
  Future<void> connect(Uri uri, Map<String, Object?> hello) async {
    await disconnect();
    _set(LinkClientState.connecting);
    final WebSocket socket;
    try {
      socket = await WebSocket.connect(uri.toString()).timeout(_connectTimeout);
    } catch (_) {
      _set(LinkClientState.disconnected);
      rethrow;
    }
    socket.pingInterval = _pingInterval;
    _socket = socket;
    socket.listen(
      (data) {
        final json = _decode(data);
        if (json != null) _messages.add(json);
      },
      onDone: () {
        if (!identical(_socket, socket)) return;
        _socket = null;
        _set(LinkClientState.disconnected);
      },
      onError: (Object e, StackTrace st) =>
          _logger.warning('Hall link error', e, st),
      cancelOnError: true,
    );
    socket.add(jsonEncode(hello));
    _set(LinkClientState.connected);
  }

  @override
  void send(Map<String, Object?> json) => _socket?.add(jsonEncode(json));

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    await socket?.close(WebSocketStatus.normalClosure);
    _set(LinkClientState.disconnected);
  }
}

/// [ILocalAddressLookup] from the network interfaces.
class LocalAddressLookupImpl implements ILocalAddressLookup {
  const LocalAddressLookupImpl();

  /// Hotspot interfaces first (Android ap/swlan, iOS bridge), then Wi-Fi.
  static int _rank(String name) {
    final n = name.toLowerCase();
    if (n.startsWith('ap') || n.startsWith('swlan') || n.startsWith('bridge')) {
      return 0;
    }
    if (n.startsWith('wlan') || n.startsWith('en')) return 1;
    return 2;
  }

  static bool _isPrivate(InternetAddress a) {
    final b = a.rawAddress;
    return b[0] == 10 ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
  }

  @override
  Future<String?> localIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final candidates = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback && _isPrivate(a)) (i.name, a.address),
    ]..sort((x, y) => _rank(x.$1).compareTo(_rank(y.$1)));
    return candidates.isEmpty ? null : candidates.first.$2;
  }
}
