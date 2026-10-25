import 'package:meta/meta.dart';

import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// This phone's part in a shared hall.
enum HallRole { none, host, member }

/// Link state shown to the invigilator. Anything but [hosting] /
/// [connected] means hall data is NOT live.
enum HallLinkStatus {
  idle,
  starting,
  hosting,
  connecting,
  connected,
  reconnecting,
  failed;

  bool get isLive => this == hosting || this == connected;
}

/// What a hall member is.
enum HallMemberKind {
  phone,

  /// Fixed ExamGuard ESP32 sensor node.
  node;

  static HallMemberKind parse(Object? value) =>
      value == 'node' ? HallMemberKind.node : HallMemberKind.phone;
}

/// A phone or node in the hall.
@immutable
class HallMember {
  const HallMember({
    required this.id,
    required this.name,
    required this.kind,
    this.isHost = false,
  });

  final String id;
  final String name;
  final HallMemberKind kind;
  final bool isHost;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'host': isHost,
  };

  static HallMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    return HallMember(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name.trim() : id,
      kind: HallMemberKind.parse(json['kind']),
      isHost: json['host'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HallMember &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.isHost == isHost;

  @override
  int get hashCode => Object.hash(id, name, kind, isHost);
}

/// A device another member of the hall currently hears.
@immutable
class RemoteDevice {
  const RemoteDevice({
    required this.device,
    required this.sourceId,
    required this.sourceName,
    required this.receivedAt,
  });

  /// As the source sees it (its RSSI, so the distance is from the source).
  final ScannedDeviceModel device;
  final String sourceId;
  final String sourceName;
  final DateTime receivedAt;

  /// Unique per source: the same device heard by two members is two rows.
  String get key => '$sourceId|${device.id}';
}

/// A new-device alert raised by another member.
@immutable
class RemoteAlert {
  const RemoteAlert({
    required this.alert,
    required this.sourceId,
    required this.sourceName,
  });

  final NewDeviceAlert alert;
  final String sourceId;
  final String sourceName;

  String get key => '$sourceId|${alert.deviceId}';

  RemoteAlert acknowledged() => RemoteAlert(
    alert: alert.copyWith(acknowledged: true),
    sourceId: sourceId,
    sourceName: sourceName,
  );
}

/// A sensor node that was in the hall and has gone (switched off,
/// unplugged, out of Wi-Fi, or tampered with).
@immutable
class OfflineNode {
  const OfflineNode({required this.member, required this.since});

  final HallMember member;
  final DateTime since;
}

/// What the host's QR code carries: where to connect and the join token.
@immutable
class HallInvite {
  const HallInvite({
    required this.host,
    required this.port,
    required this.token,
    required this.room,
  });

  static const String scheme = 'examguard';

  final String host;
  final int port;
  final String token;
  final String room;

  Uri get socketUri => Uri(scheme: 'ws', host: host, port: port);

  /// `examguard://join?h=192.168.43.1&p=47800&t=TOKEN&r=ROOM`
  String encode() => Uri(
    scheme: scheme,
    host: 'join',
    queryParameters: {'h': host, 'p': '$port', 't': token, 'r': room},
  ).toString();

  /// Null for anything that isn't an ExamGuard hall invite.
  static HallInvite? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != scheme || uri.host != 'join') {
      return null;
    }
    final q = uri.queryParameters;
    final host = q['h'] ?? '';
    final port = int.tryParse(q['p'] ?? '');
    final token = q['t'] ?? '';
    if (host.isEmpty || port == null || port <= 0 || token.isEmpty) {
      return null;
    }
    return HallInvite(host: host, port: port, token: token, room: q['r'] ?? '');
  }
}
