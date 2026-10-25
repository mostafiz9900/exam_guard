import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/local_link/local_link_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// One JSON message received by the hub, with the peer that sent it.
class LinkMessage {
  const LinkMessage(this.peerId, this.json);

  final String peerId;
  final Map<String, Object?> json;
}

/// A peer joined ([hello] is its first message) or left ([hello] is null).
class LinkPeerEvent {
  const LinkPeerEvent.joined(this.peerId, Map<String, Object?> this.hello);
  const LinkPeerEvent.left(this.peerId) : hello = null;

  final String peerId;
  final Map<String, Object?>? hello;

  bool get joined => hello != null;
}

/// Result of a peer's first message: the id to register it under, or null
/// to refuse it with [rejectReply].
typedef LinkAcceptor = String? Function(Map<String, Object?> hello);

/// Local-network hub: a WebSocket server other devices on the same Wi-Fi /
/// hotspot connect to. Carries JSON objects; what they mean is up to the
/// caller. Features use this instead of `dart:io` sockets.
abstract interface class ILocalLinkHub {
  /// Starts listening on [port] (0 = any free port) and returns the port.
  /// Each connection's first message goes to [accept]; refused peers get
  /// [rejectReply] and are closed.
  Future<int> start({
    required int port,
    required LinkAcceptor accept,
    required Map<String, Object?> Function(Map<String, Object?> hello)
    rejectReply,
  });

  Stream<LinkMessage> get messages;
  Stream<LinkPeerEvent> get peers;

  void sendTo(String peerId, Map<String, Object?> json);

  /// Sends to every peer except [except].
  void broadcast(Map<String, Object?> json, {String? except});

  Future<void> stop();

  bool get isRunning;
}

/// Connection state of [ILocalLinkClient].
enum LinkClientState { disconnected, connecting, connected }

/// Local-network client of an [ILocalLinkHub].
abstract interface class ILocalLinkClient {
  /// Connects to [uri] (ws://host:port) and sends [hello] first.
  /// Throws when the hub can't be reached.
  Future<void> connect(Uri uri, Map<String, Object?> hello);

  Stream<Map<String, Object?>> get messages;

  /// Current state first, then every change.
  Stream<LinkClientState> get state;

  void send(Map<String, Object?> json);

  Future<void> disconnect();
}

/// This device's IPv4 address on the local network (hotspot interface
/// first), or null when it has none.
abstract interface class ILocalAddressLookup {
  Future<String?> localIpv4();
}

final localLinkHubProvider = Provider<ILocalLinkHub>((ref) {
  final hub = LocalLinkHubImpl(ref.watch(appLoggerProvider));
  ref.onDispose(hub.stop);
  return hub;
});

final localLinkClientProvider = Provider<ILocalLinkClient>((ref) {
  final client = LocalLinkClientImpl(ref.watch(appLoggerProvider));
  ref.onDispose(client.disconnect);
  return client;
});

final localAddressLookupProvider = Provider<ILocalAddressLookup>(
  (ref) => const LocalAddressLookupImpl(),
);
