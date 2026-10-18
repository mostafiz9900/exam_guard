import 'package:flutter/foundation.dart';

import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// One past exam as the history list shows it.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.sessionId,
    required this.roomNumber,
    required this.instituteName,
    required this.startTime,
    required this.duration,
    required this.incidentCount,
    required this.criticalCount,
    required this.isRunning,
  });

  factory HistoryEntry.fromSession(SessionModel session) => HistoryEntry(
    sessionId: session.id,
    roomNumber: session.roomNumber,
    instituteName: session.instituteName,
    startTime: session.startTime,
    duration: session.duration,
    incidentCount: session.deviceLogs.length,
    criticalCount: session.deviceLogs
        .where((l) => l.severity == LogSeverity.critical)
        .length,
    isRunning: session.isActive,
  );

  final String sessionId;
  final String roomNumber;
  final String instituteName;
  final DateTime startTime;

  /// Exam length (until now for an exam that never ended).
  final Duration duration;
  final int incidentCount;
  final int criticalCount;

  /// The exam has no end time. Its report is not opened from history.
  final bool isRunning;
}
