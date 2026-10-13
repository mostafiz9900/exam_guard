import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/local_storage/hive_storage_impl.dart';
import 'package:exam_guard/core/services/local_storage/i_local_storage.dart';
import 'package:exam_guard/features/session/domain/session_model.dart';

/// Global provider for session state.
/// The state holds the active session, the just-ended session (until a new
/// one starts), or null.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionModel?>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<SessionModel?> {
  late ILocalStorage _storage;

  @override
  Future<SessionModel?> build() async {
    _storage = ref.watch(localStorageProvider);
    return _storage.getCurrentSession();
  }

  /// Create and persist a new session. Generates a simple id if caller doesn't.
  Future<void> createSession({
    String? id,
    required String instituteName,
    required String teacherName,
    required String roomNumber,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = SessionModel(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        instituteName: instituteName,
        teacherName: teacherName,
        roomNumber: roomNumber,
        startTime: DateTime.now(),
      );
      await _storage.saveSession(session);
      return session;
    });
    if (state case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Stamps the end time, persists it, and keeps the ended session in state
  /// so the report screen can show and export it.
  Future<SessionModel?> endCurrentSession() async {
    final current = state.value;
    if (current == null || current.endTime != null) return current;
    final ended = current.copyWith(endTime: DateTime.now());
    await _storage.endSession(ended);
    state = AsyncValue.data(ended);
    return ended;
  }

  Future<void> addLog(Map<String, dynamic> log) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(deviceLogs: [...current.deviceLogs, log]);
    if (current.endTime == null) {
      await _storage.saveSession(updated);
    } else {
      await _storage.endSession(updated);
    }
    state = AsyncValue.data(updated);
  }
}
