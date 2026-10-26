import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';

/// Room profiles, stored under `room_profile_<normalized room>`.
class RoomProfileRepository {
  RoomProfileRepository(this._storage);

  static const String _prefix = 'room_profile_';

  final ILocalStorage _storage;

  String _key(String room) => '$_prefix${RoomProfile.keyOf(room)}';

  /// Null when [room] is empty or has no saved equipment.
  RoomProfile? load(String room) {
    if (RoomProfile.keyOf(room).isEmpty) return null;
    final p = RoomProfile.fromJson(_storage.read<Object>(_key(room)));
    return p == null || p.items.isEmpty ? null : p;
  }

  Future<void> save(RoomProfile profile) =>
      _storage.write(_key(profile.room), profile.toJson());

  Future<void> delete(String room) => _storage.delete(_key(room));
}

final roomProfileRepositoryProvider = Provider<RoomProfileRepository>(
  (ref) => RoomProfileRepository(ref.watch(localStorageProvider)),
);
