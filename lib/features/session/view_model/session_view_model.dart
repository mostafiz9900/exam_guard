import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/repository/session_repository.dart';

/// The active session, the just-ended session (until a new one starts),
/// or null.
class SessionViewModel extends AsyncNotifier<SessionModel?> {
  late SessionRepository _repository;

  @override
  Future<SessionModel?> build() async {
    _repository = ref.watch(sessionRepositoryProvider);
    return _repository.currentSession();
  }

  Future<void> createSession({
    required String instituteName,
    required String teacherName,
    required String roomNumber,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = SessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        instituteName: instituteName,
        teacherName: teacherName,
        roomNumber: roomNumber,
        startTime: DateTime.now(),
      );
      await _repository.saveActive(session);
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
    await _repository.saveEnded(ended);
    state = AsyncValue.data(ended);
    return ended;
  }

  Future<void> addLog(ActionLogModel log) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(deviceLogs: [...current.deviceLogs, log]);
    if (current.endTime == null) {
      await _repository.saveActive(updated);
    } else {
      await _repository.saveEnded(updated);
    }
    state = AsyncValue.data(updated);
  }
}

final sessionViewModelProvider =
    AsyncNotifierProvider<SessionViewModel, SessionModel?>(
      SessionViewModel.new,
    );
