import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Persists exam sessions. Each session is stored under `session_<id>`.
/// `current_session_id` points at the running exam, `last_session_id` at the
/// most recent one (running or ended) so its report survives a restart.
class SessionRepository {
  SessionRepository(this._storage);

  static const _currentKey = 'current_session_id';
  static const _lastKey = 'last_session_id';
  static const _prefix = 'session_';

  final ILocalStorage _storage;

  /// The exam that is still running, if any.
  SessionModel? activeSession() {
    final id = _storage.read<String>(_currentKey);
    final session = id == null ? null : _load('$_prefix$id');
    return session != null && session.isActive ? session : null;
  }

  /// The most recent exam, running or ended.
  SessionModel? lastSession() {
    final id = _storage.read<String>(_lastKey);
    return id == null ? null : _load('$_prefix$id');
  }

  Future<void> save(SessionModel session) async {
    await _storage.write('$_prefix${session.id}', session.toJson());
    await _storage.write(_lastKey, session.id);
    if (session.isActive) {
      await _storage.write(_currentKey, session.id);
    } else if (_storage.read<String>(_currentKey) == session.id) {
      await _storage.delete(_currentKey);
    }
  }

  List<SessionModel> allSessions() => [
    for (final key in _storage.keys)
      if (key.startsWith(_prefix)) ?_load(key),
  ]..sort((a, b) => b.startTime.compareTo(a.startTime));

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
