import 'package:exam_guard/features/session/domain/session_model.dart';

/// Storage abstraction used by the application layer.
/// Implementations should handle persistence details (Hive, SQLite, files).
abstract class ILocalStorage {
  /// Persist a session. If the session is new it should be created,
  /// otherwise updated.
  Future<void> saveSession(SessionModel session);

  /// Return the currently active session or `null` if none.
  Future<SessionModel?> getCurrentSession();

  /// Mark the given session as ended and persist the change.
  Future<void> endSession(SessionModel session);

  /// Return all stored sessions.
  Future<List<SessionModel>> getAllSessions();

  /// Close any resources (boxes, file handles).
  Future<void> dispose();
}
