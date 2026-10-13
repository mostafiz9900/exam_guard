import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/repository/session_repository.dart';

/// Thrown when an incident is logged without a running exam.
class NoActiveSessionException implements Exception {
  const NoActiveSessionException();

  @override
  String toString() => 'No exam session is running.';
}

/// The running exam, or the exam whose report is being viewed, or null.
class SessionViewModel extends Notifier<SessionModel?> {
  late SessionRepository _repository;

  @override
  SessionModel? build() {
    _repository = ref.watch(sessionRepositoryProvider);
    return _repository.activeSession();
  }

  /// The most recent exam, so its report can be reopened after a restart.
  SessionModel? get lastSession => _repository.lastSession();

  Future<void> createSession({
    required String instituteName,
    required String teacherName,
    required String roomNumber,
  }) async {
    // Never leave a running exam orphaned.
    final running = state;
    if (running != null && running.isActive) {
      await _repository.save(running.copyWith(endTime: DateTime.now()));
    }
    final session = SessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      instituteName: instituteName,
      teacherName: teacherName,
      roomNumber: roomNumber,
      startTime: DateTime.now(),
    );
    await _repository.save(session);
    state = session;
  }

  /// Stamps the end time and keeps the ended session in state for the report.
  Future<SessionModel?> endCurrentSession() async {
    final current = state;
    if (current == null || !current.isActive) return current;
    final ended = current.copyWith(endTime: DateTime.now());
    await _repository.save(ended);
    state = ended;
    return ended;
  }

  /// Shows the last exam's report (read-only).
  void openLastSession() => state = _repository.lastSession();

  /// Clears an ended session so a new exam can be set up.
  void closeEndedSession() {
    if (state != null && !state!.isActive) state = null;
  }

  Future<void> addLog(ActionLogModel log) async {
    final current = state;
    if (current == null || !current.isActive) {
      throw const NoActiveSessionException();
    }
    final updated = current.copyWith(deviceLogs: [...current.deviceLogs, log]);
    await _repository.save(updated);
    state = updated;
  }
}

final sessionViewModelProvider =
    NotifierProvider<SessionViewModel, SessionModel?>(SessionViewModel.new);
