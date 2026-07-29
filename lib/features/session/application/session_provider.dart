import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:exam_guard/features/session/domain/session_model.dart';
import 'package:exam_guard/core/services/local_storage/hive_storage_impl.dart';
import 'package:exam_guard/core/services/local_storage/i_local_storage.dart';

/// Global provider for session state.
/// The state holds the currently active session or null.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionModel?>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<SessionModel?> {
  late final ILocalStorage _storage;
  Timer? _ticker;

  @override
  Future<SessionModel?> build() async {
    // Acquire storage from the provided dependency.
    _storage = ref.read(localStorageProvider);
    final current = await _storage.getCurrentSession();
    // If a session exists, we could start an internal timer here to track
    // elapsed time. Keep it lightweight for now.
    // Ensure we stop the ticker when the provider is disposed.
    ref.onDispose(() {
      _stopTicker();
    });
    return current;
  }

  /// Create and persist a new session. Generates a simple id if caller doesn't.
  Future<void> createSession({
    String? id,
    required String instituteName,
    required String teacherName,
    required String roomNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = SessionModel(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        instituteName: instituteName,
        teacherName: teacherName,
        roomNumber: roomNumber,
        startTime: DateTime.now(),
      );

      await _storage.saveSession(session);
      // Optionally start a ticker if the UI needs periodic updates.
      _startTicker();
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> endCurrentSession() async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    try {
      final ended = current.copyWith(endTime: DateTime.now());
      await _storage.endSession(ended);
      _stopTicker();
      state = AsyncValue.data(ended);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> addLog(Map<String, dynamic> log) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(deviceLogs: [...current.deviceLogs, log]);
    await _storage.saveSession(updated);
    state = AsyncValue.data(updated);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger UI updates if necessary. We don't change the session model
      // here, but notifying listeners can be done by reassigning the same
      // value — avoid excessive updates in production.
      state = AsyncValue.data(state.value);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // cleanup is handled via `ref.onDispose` to avoid overriding internal
  // notifier lifecycle hooks directly.
}
