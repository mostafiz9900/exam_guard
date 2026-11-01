import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Bluetooth setup of an Pahara ESP32 sensor node (protocol v1).
///
/// In setup mode (first start, or BOOT held 3 s) the node advertises as
/// `Pahara-Setup-A1B2C3` with [service]. The app reads [info] and
/// [networks], writes a config to [config], and follows [status]
/// notifications while the node tests the Wi-Fi and the host phone.
/// Firmware: firmware/esp32/src/main.cpp ("Setup").
abstract final class NodeSetupProtocol {
  static const int version = 1;

  static const String service = 'e9a40001-5c1d-4b6a-9e2f-3d8c7b1a0e01';
  static const String info = 'e9a40002-5c1d-4b6a-9e2f-3d8c7b1a0e01';
  static const String networks = 'e9a40003-5c1d-4b6a-9e2f-3d8c7b1a0e01';
  static const String config = 'e9a40004-5c1d-4b6a-9e2f-3d8c7b1a0e01';
  static const String status = 'e9a40005-5c1d-4b6a-9e2f-3d8c7b1a0e01';

  static const String namePrefix = 'Pahara-Setup-';

  /// A node in setup mode, by its advertisement.
  static bool isSetupNode(String name, List<String> serviceUuids) =>
      name.startsWith(namePrefix) ||
      serviceUuids.any((u) => u.toLowerCase() == service);

  /// `Pahara-Setup-A1B2C3` → `N-A1B2C3`, the id it uses in the hall.
  static String? nodeIdFromName(String name) =>
      name.startsWith(namePrefix) && name.length > namePrefix.length
      ? 'N-${name.substring(namePrefix.length)}'
      : null;

  static List<int> encodeConfig(NodeSetupConfig c) => utf8.encode(
    jsonEncode({
      'v': version,
      'ssid': c.ssid,
      'pass': c.password,
      'key': c.nodeKey,
      'name': c.name,
      'hub': c.hub,
    }),
  );

  static List<int> encodeScanRequest() =>
      utf8.encode(jsonEncode({'v': version, 'cmd': 'scan'}));

  static Map<String, Object?>? _json(List<int> bytes) {
    try {
      final v = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      return v is Map<String, Object?> ? v : null;
    } catch (_) {
      return null;
    }
  }

  static NodeSetupInfo? decodeInfo(List<int> bytes) {
    final j = _json(bytes);
    final id = j?['id'];
    if (j == null || id is! String || id.isEmpty) return null;
    return NodeSetupInfo(
      id: id,
      name: j['name'] is String ? j['name']! as String : id,
      firmware: j['fw'] is String ? j['fw']! as String : '',
      hasKey: j['key'] == true,
      savedSsid: j['ssid'] is String ? j['ssid']! as String : null,
      protocolVersion: j['v'] is int ? j['v']! as int : 0,
    );
  }

  static List<NodeNetwork> decodeNetworks(List<int> bytes) {
    Object? v;
    try {
      v = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return const [];
    }
    if (v is! List) return const [];
    return [
      for (final o in v)
        if (o is Map && o['s'] is String && (o['s'] as String).isNotEmpty)
          NodeNetwork(
            ssid: o['s'] as String,
            rssi: o['r'] is int ? o['r'] as int : -100,
            isOpen: o['o'] == 1,
          ),
    ];
  }

  static NodeSetupUpdate? decodeStatus(List<int> bytes) {
    final j = _json(bytes);
    final s = j?['s'];
    if (s is! String) return null;
    return NodeSetupUpdate(
      NodeSetupStatus.parse(s),
      j!['d'] is String ? j['d']! as String : null,
    );
  }
}

/// What the node says about itself.
@immutable
class NodeSetupInfo {
  const NodeSetupInfo({
    required this.id,
    required this.name,
    required this.firmware,
    required this.hasKey,
    required this.protocolVersion,
    this.savedSsid,
  });

  /// Hall member id, e.g. `N-A1B2C3`.
  final String id;
  final String name;
  final String firmware;
  final bool hasKey;
  final int protocolVersion;

  /// Hotspot it was set up with before, if any.
  final String? savedSsid;
}

/// A Wi-Fi network the node can see (2.4 GHz only).
@immutable
class NodeNetwork {
  const NodeNetwork({
    required this.ssid,
    required this.rssi,
    required this.isOpen,
  });

  final String ssid;
  final int rssi;
  final bool isOpen;
}

@immutable
class NodeSetupConfig {
  const NodeSetupConfig({
    required this.ssid,
    required this.password,
    required this.nodeKey,
    this.name = '',
    this.hub = '',
  });

  final String ssid;
  final String password;
  final String nodeKey;

  /// Empty = automatic (`Pahara-Node-A1B2C3`).
  final String name;

  /// Host phone address; empty = the hotspot's gateway (the host phone).
  final String hub;
}

/// The node's progress while it applies a config.
enum NodeSetupStatus {
  ready,
  scanning,
  joining,
  wifiOk,
  hostOk,

  /// Wi-Fi works but nothing answers on the hall port: the hall isn't
  /// hosted yet. Not an error — the node keeps trying after restart.
  noHost,

  /// Settings stored; the node restarts and joins the hall.
  saved,
  noNetwork,
  badPassword,
  wifiFailed,
  badRequest,
  unknown;

  static NodeSetupStatus parse(String s) => switch (s) {
    'ready' => ready,
    'scanning' => scanning,
    'joining' => joining,
    'wifi_ok' => wifiOk,
    'host_ok' => hostOk,
    'no_host' => noHost,
    'saved' => saved,
    'no_network' => noNetwork,
    'bad_password' => badPassword,
    'wifi_failed' => wifiFailed,
    'bad_request' => badRequest,
    _ => unknown,
  };

  bool get isFailure =>
      this == noNetwork ||
      this == badPassword ||
      this == wifiFailed ||
      this == badRequest;
}

@immutable
class NodeSetupUpdate {
  const NodeSetupUpdate(this.status, [this.detail]);

  final NodeSetupStatus status;

  /// SSID, IP address or node name, depending on [status].
  final String? detail;
}

/// A node in setup mode found nearby.
@immutable
class SetupNodeCandidate {
  const SetupNodeCandidate({
    required this.deviceId,
    required this.name,
    required this.rssi,
    required this.lastSeen,
  });

  /// Bluetooth id to connect to.
  final String deviceId;
  final String name;
  final int rssi;
  final DateTime lastSeen;

  /// `A1B2C3` — matches the sticker-free way to tell boards apart: the
  /// serial log and the setup Wi-Fi name show the same code.
  String get code => name.startsWith(NodeSetupProtocol.namePrefix)
      ? name.substring(NodeSetupProtocol.namePrefix.length)
      : deviceId;
}
