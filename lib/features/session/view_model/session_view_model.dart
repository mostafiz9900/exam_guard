import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/session/model/activity_sample.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';
import 'package:exam_guard/features/session/repository/room_profile_repository.dart';
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
  late RoomProfileRepository _profiles;

  @override
  SessionModel? build() {
    _repository = ref.watch(sessionRepositoryProvider);
    _profiles = ref.watch(roomProfileRepositoryProvider);
    return _repository.activeSession();
  }

  /// The most recent exam, so its report can be reopened after a restart.
  SessionModel? get lastSession => _repository.lastSession();

  Future<void> createSession({
    required String instituteName,
    required String teacherName,
    required String roomNumber,
    int? seatRows,
    int? seatCols,
  }) async {
    // Never leave a running exam orphaned.
    final running = state;
    if (running != null && running.isActive) {
      await _repository.save(running.copyWith(endTime: DateTime.now()));
    }
    // This room's remembered equipment starts out trusted.
    final profile = _profiles.load(roomNumber);
    final session = SessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      instituteName: instituteName,
      teacherName: teacherName,
      roomNumber: roomNumber,
      startTime: DateTime.now(),
      seatRows: seatRows,
      seatCols: seatCols,
      trustedDeviceIds: profile?.ids ?? const {},
      profileDeviceIds: profile?.ids ?? const {},
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

  /// Shows the last exam's report (read-only). Returns false when there is
  /// no saved exam to show, leaving the current state untouched.
  bool openLastSession() {
    final last = _repository.lastSession();
    if (last == null) return false;
    state = last;
    return true;
  }

  /// Clears an ended session so a new exam can be set up.
  void closeEndedSession() {
    if (state != null && !state!.isActive) state = null;
  }

  /// Every saved exam, newest first (for the exam history screen).
  List<SessionModel> get allSessions => _repository.allSessions();

  /// Shows a saved exam's report (read-only). False if it doesn't exist.
  bool openSession(String id) {
    for (final s in _repository.allSessions()) {
      if (s.id == id) {
        state = s;
        return true;
      }
    }
    return false;
  }

  /// Records the empty-room baseline: every device seen now is trusted.
  Future<void> setBaseline(Set<String> deviceIds) => _updateActive(
    (s) => s.copyWith(
      trustedDeviceIds: {...s.trustedDeviceIds, ...deviceIds},
      baselineAt: DateTime.now(),
    ),
  );

  /// Saved equipment of [room] (or the running exam's room), or null.
  RoomProfile? roomProfile([String? room]) =>
      _profiles.load(room ?? state?.roomNumber ?? '');

  /// Adds [items] to the running exam's room profile (after a baseline);
  /// returns how many devices the profile now holds.
  Future<int> rememberRoomEquipment(List<RoomProfileItem> items) async {
    final s = state;
    if (s == null || items.isEmpty) return roomProfile()?.items.length ?? 0;
    final merged = {
      for (final i in roomProfile()?.items ?? const <RoomProfileItem>[])
        i.id: i,
      for (final i in items) i.id: i,
    };
    await _profiles.save(
      RoomProfile(
        room: s.roomNumber,
        savedAt: DateTime.now(),
        items: merged.values.toList(),
      ),
    );
    return merged.length;
  }

  /// Removes one remembered device (it stays trusted in this exam).
  Future<void> forgetRoomEquipment(String deviceId) async {
    final p = roomProfile();
    if (p == null) return;
    final rest = [
      for (final i in p.items)
        if (i.id != deviceId) i,
    ];
    if (rest.isEmpty) {
      await _profiles.delete(p.room);
    } else {
      await _profiles.save(
        RoomProfile(room: p.room, savedAt: DateTime.now(), items: rest),
      );
    }
  }

  /// Forgets everything remembered for [room] (default: this exam's room).
  Future<void> forgetRoomProfile([String? room]) =>
      _profiles.delete(room ?? state?.roomNumber ?? '');

  /// Appends one "devices in range" sample to the running exam.
  Future<void> addActivitySample(ActivitySample sample) =>
      _updateActive((s) => s.copyWith(activity: [...s.activity, sample]));

  /// Marks one device as belonging to the room/invigilator.
  Future<void> trustDevice(String deviceId) => _updateActive(
    (s) => s.copyWith(trustedDeviceIds: {...s.trustedDeviceIds, deviceId}),
  );

  Future<void> untrustDevice(String deviceId) => _updateActive(
    (s) =>
        s.copyWith(trustedDeviceIds: {...s.trustedDeviceIds}..remove(deviceId)),
  );

  Future<void> setSeatLayout({required int rows, required int cols}) =>
      _updateActive((s) => s.copyWith(seatRows: rows, seatCols: cols));

  Future<void> _updateActive(SessionModel Function(SessionModel) change) async {
    final current = state;
    if (current == null || !current.isActive) {
      throw const NoActiveSessionException();
    }
    final updated = change(current);
    await _repository.save(updated);
    state = updated;
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
