import 'package:meta/meta.dart';

/// One piece of fixed room equipment (router, projector, printer…).
@immutable
class RoomProfileItem {
  const RoomProfileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.transport,
  });

  final String id;
  final String name;

  /// English category, as in the scanner.
  final String type;

  /// `ble`, `classic` or `wifi`.
  final String transport;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'tx': transport,
  };

  static RoomProfileItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return RoomProfileItem(
      id: id,
      name: json['name'] is String ? json['name']! as String : '',
      type: json['type'] is String ? json['type']! as String : '',
      transport: json['tx'] is String ? json['tx']! as String : 'ble',
    );
  }
}

/// The equipment remembered for one exam room, so the next exam there
/// starts with it already trusted.
@immutable
class RoomProfile {
  const RoomProfile({
    required this.room,
    required this.savedAt,
    required this.items,
  });

  /// Room number as typed when it was saved.
  final String room;
  final DateTime savedAt;
  final List<RoomProfileItem> items;

  Set<String> get ids => {for (final i in items) i.id};

  /// Same room however it is typed: "302-B", " 302 - b", "302B".
  static String keyOf(String room) =>
      room.toLowerCase().replaceAll(RegExp(r'[\s\-_/.]+'), '');

  Map<String, dynamic> toJson() => {
    'room': room,
    'savedAt': savedAt.millisecondsSinceEpoch,
    'items': [for (final i in items) i.toJson()],
  };

  static RoomProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final saved = json['savedAt'];
    return RoomProfile(
      room: json['room'] is String ? json['room']! as String : '',
      savedAt: DateTime.fromMillisecondsSinceEpoch(saved is int ? saved : 0),
      items: [
        for (final i in (json['items'] as List?) ?? const [])
          ?RoomProfileItem.fromJson(i),
      ],
    );
  }
}
