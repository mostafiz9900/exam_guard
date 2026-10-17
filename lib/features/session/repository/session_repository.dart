import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Persists exam sessions. Each session is stored under `session_<id>`.
/// `current_session_id` points at the running exam, `last_session_id` at the
/// most recent one (running or ended) so its report survives a restart.
class SessionRepository {
  SessionRepository(this._storage, this._logger);

  static const _currentKey = 'current_session_id';
  static const _lastKey = 'last_session_id';
  static const _prefix = 'session_';

  final ILocalStorage _storage;
  final AppLogger _logger;

  /// The exam that is still running, if any.
  SessionModel? activeSession() {
    final id = _storage.read<String>(_currentKey);
    final session = id == null ? null : _load('$_prefix$id');
    if (session != null && session.isActive) return session;
    // The pointer write may have failed; a running last session still counts.
    final last = lastSession();
    return last != null && last.isActive ? last : null;
  }

  /// The most recent exam, running or ended.
  SessionModel? lastSession() {
    final id = _storage.read<String>(_lastKey);
    return id == null ? null : _load('$_prefix$id');
  }

  /// Writes the session itself; failure here throws. The pointer keys are
  /// best-effort: the data is already persisted, so their failures are only
  /// logged (`activeSession` falls back to the last session).
  Future<void> save(SessionModel session) async {
    await _storage.write('$_prefix${session.id}', session.toJson());
    try {
      await _storage.write(_lastKey, session.id);
      if (session.isActive) {
        await _storage.write(_currentKey, session.id);
      } else if (_storage.read<String>(_currentKey) == session.id) {
        await _storage.delete(_currentKey);
      }
    } catch (e, st) {
      _logger.warning('Updating session pointers failed', e, st);
    }
  }

  List<SessionModel> allSessions() => [
    for (final key in _storage.keys)
      if (key.startsWith(_prefix)) ?_load(key),
  ]..sort((a, b) => b.startTime.compareTo(a.startTime));

  /// Returns null (and logs) for missing or unreadable entries, so one
  /// corrupt record never crashes startup.
  SessionModel? _load(String key) {
    try {
      final raw = _storage.read<Map<dynamic, dynamic>>(key);
      return raw == null
          ? null
          : SessionModel.fromJson(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      _logger.error('Skipping unreadable session "$key"', e, st);
      return null;
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    ref.watch(localStorageProvider),
    ref.watch(appLoggerProvider),
  ),
);
