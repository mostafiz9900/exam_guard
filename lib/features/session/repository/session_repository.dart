import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Persists exam sessions. Each session is stored under `session_<id>`;
/// `current_session_id` points at the active one.
class SessionRepository {
  SessionRepository(this._storage);

  static const _currentKey = 'current_session_id';
  static const _prefix = 'session_';

  final ILocalStorage _storage;

  Future<SessionModel?> currentSession() async {
    final id = _storage.read<String>(_currentKey);
    return id == null ? null : _load('$_prefix$id');
  }

  /// Saves an active session and marks it as the current one.
  Future<void> saveActive(SessionModel session) async {
    await _storage.write('$_prefix${session.id}', session.toJson());
    await _storage.write(_currentKey, session.id);
  }

  /// Saves an ended session; it is no longer the current one.
  Future<void> saveEnded(SessionModel session) async {
    await _storage.write('$_prefix${session.id}', session.toJson());
    if (_storage.read<String>(_currentKey) == session.id) {
      await _storage.delete(_currentKey);
    }
  }

  Future<List<SessionModel>> allSessions() async => [
    for (final key in _storage.keys)
      if (key.startsWith(_prefix)) ?_load(key),
  ];

  SessionModel? _load(String key) {
    final raw = _storage.read<Map<dynamic, dynamic>>(key);
    return raw == null
        ? null
        : SessionModel.fromJson(Map<String, dynamic>.from(raw));
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(localStorageProvider)),
);
