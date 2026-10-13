import 'package:exam_guard/core/services/local_storage/hive_storage_impl.dart';
import 'package:exam_guard/core/services/local_storage/i_local_storage.dart';
import 'package:exam_guard/features/session/application/session_provider.dart';
import 'package:exam_guard/features/session/domain/session_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class InMemoryStorage implements ILocalStorage {
  final sessions = <String, SessionModel>{};
  String? currentId;

  @override
  Future<void> saveSession(SessionModel session) async {
    sessions[session.id] = session;
    currentId = session.id;
  }

  @override
  Future<SessionModel?> getCurrentSession() async =>
      currentId == null ? null : sessions[currentId];

  @override
  Future<void> endSession(SessionModel session) async {
    sessions[session.id] = session;
    currentId = null;
  }

  @override
  Future<List<SessionModel>> getAllSessions() async =>
      sessions.values.toList();

  @override
  Future<void> dispose() async {}
}

void main() {
  test('ending the exam records the end time and keeps the report data',
      () async {
    final storage = InMemoryStorage();
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.future);
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createSession(
      instituteName: 'Test School',
      teacherName: 'Inspector',
      roomNumber: '12',
    );
    await notifier.addLog({'name': 'Phone', 'severity': 'HIGH'});

    final ended = await notifier.endCurrentSession();

    expect(ended?.endTime, isNotNull);
    expect(storage.sessions.values.single.endTime, isNotNull);
    expect(storage.currentId, isNull);
    expect(container.read(sessionProvider).value?.deviceLogs, hasLength(1));
  });
}
