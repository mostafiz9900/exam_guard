import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';

/// Where each sensor node sits on a room's seat map, kept per room so the
/// next exam in the same room needs no placing.
class HallMapRepository {
  HallMapRepository(this._storage);

  final ILocalStorage _storage;

  static String _key(String room) =>
      'hall_map_nodes_${RoomProfile.keyOf(room)}';

  /// Node id → zero-based (row, col).
  Map<String, (int, int)> placements(String room) {
    final raw = _storage.read<String>(_key(room));
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      return {
        for (final e in json.entries)
          if (e.key is String &&
              e.value is List &&
              (e.value as List).length == 2)
            e.key as String: (
              ((e.value as List)[0] as num).toInt(),
              ((e.value as List)[1] as num).toInt(),
            ),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Throws [StorageException].
  Future<void> save(String room, Map<String, (int, int)> placements) =>
      _storage.write(
        _key(room),
        jsonEncode({
          for (final e in placements.entries) e.key: [e.value.$1, e.value.$2],
        }),
      );
}

final hallMapRepositoryProvider = Provider<HallMapRepository>(
  (ref) => HallMapRepository(ref.watch(localStorageProvider)),
);
