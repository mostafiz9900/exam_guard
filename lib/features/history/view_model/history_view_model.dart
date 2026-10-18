import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/history/model/history_entry.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

export 'package:exam_guard/features/history/model/history_entry.dart';

class HistoryState {
  const HistoryState({this.entries = const [], this.examRunning = false});

  /// Every saved exam, newest first.
  final List<HistoryEntry> entries;

  /// An exam is running; old reports cannot be opened until it ends.
  final bool examRunning;

  bool get isEmpty => entries.isEmpty;
}

/// Past exams. Reads the saved sessions on build and whenever the current
/// session changes.
class HistoryViewModel extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    final current = ref.watch(sessionViewModelProvider);
    return _load(examRunning: current != null && current.isActive);
  }

  /// Re-reads the saved exams.
  void refresh() {
    final current = ref.read(sessionViewModelProvider);
    state = _load(examRunning: current != null && current.isActive);
  }

  HistoryState _load({required bool examRunning}) {
    final sessions = ref.read(sessionViewModelProvider.notifier).allSessions;
    final entries = [for (final s in sessions) HistoryEntry.fromSession(s)]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return HistoryState(entries: entries, examRunning: examRunning);
  }

  /// Makes [sessionId] the session the report screen shows. Refused (false)
  /// while an exam is running, so a running exam is never replaced, and for
  /// an exam without an end time.
  bool openReport(String sessionId) {
    if (state.examRunning) return false;
    final entry = state.entries.where((e) => e.sessionId == sessionId);
    if (entry.isEmpty || entry.first.isRunning) return false;
    return ref.read(sessionViewModelProvider.notifier).openSession(sessionId);
  }
}

final historyViewModelProvider =
    NotifierProvider.autoDispose<HistoryViewModel, HistoryState>(
      HistoryViewModel.new,
    );
