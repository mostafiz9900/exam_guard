import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/history/view_model/history_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _MemoryStorage implements ILocalStorage {
  final values = <String, Object?>{};

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;

  @override
  T? read<T>(String key) {
    final v = values[key];
    return v is T ? v : null;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Iterable<String> get keys => values.keys;

  @override
  Future<void> dispose() async {}
}

ActionLogModel _log(LogSeverity severity) => ActionLogModel(
  deviceName: 'Phone',
  deviceId: 'AA',
  category: 'Bluetooth Device',
  severity: severity,
  location: 'Desk 1',
  notes: '',
  createdAt: DateTime(2026, 10, 1),
);

SessionModel _session(
  String id,
  DateTime start, {
  bool ended = true,
  List<ActionLogModel> logs = const [],
}) => SessionModel(
  id: id,
  instituteName: 'School $id',
  teacherName: 'T',
  roomNumber: 'R$id',
  startTime: start,
  endTime: ended ? start.add(const Duration(hours: 2)) : null,
  deviceLogs: logs,
);

void _store(_MemoryStorage storage, SessionModel s, {bool current = false}) {
  storage.values['session_${s.id}'] = s.toJson();
  storage.values['last_session_id'] = s.id;
  if (current) storage.values['current_session_id'] = s.id;
}

ProviderContainer _container(_MemoryStorage storage) {
  final container = ProviderContainer(
    overrides: [localStorageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose provider alive for the whole test.
  container.listen(historyViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('no saved exams gives an empty history', () {
    final container = _container(_MemoryStorage());
    final state = container.read(historyViewModelProvider);
    expect(state.isEmpty, isTrue);
    expect(state.examRunning, isFalse);
  });

  test('lists exams newest first with incident and critical counts', () {
    final storage = _MemoryStorage();
    _store(storage, _session('b', DateTime(2026, 10, 2)));
    _store(
      storage,
      _session(
        'c',
        DateTime(2026, 10, 3),
        logs: [_log(LogSeverity.critical), _log(LogSeverity.low)],
      ),
    );
    _store(storage, _session('a', DateTime(2026, 10, 1)));

    final entries = _container(storage).read(historyViewModelProvider).entries;

    expect(entries.map((e) => e.sessionId), ['c', 'b', 'a']);
    expect(entries.first.incidentCount, 2);
    expect(entries.first.criticalCount, 1);
    expect(entries.first.duration, const Duration(hours: 2));
    expect(entries.first.roomNumber, 'Rc');
  });

  test('opening a report selects that ended exam', () {
    final storage = _MemoryStorage();
    _store(storage, _session('a', DateTime(2026, 10, 1)));
    _store(storage, _session('b', DateTime(2026, 10, 2)));
    final container = _container(storage);

    final opened = container
        .read(historyViewModelProvider.notifier)
        .openReport('a');

    expect(opened, isTrue);
    expect(container.read(sessionViewModelProvider)?.id, 'a');
  });

  test('a running exam is never replaced by an old report', () {
    final storage = _MemoryStorage();
    _store(storage, _session('old', DateTime(2026, 10, 1)));
    _store(
      storage,
      _session('live', DateTime(2026, 10, 2), ended: false),
      current: true,
    );
    final container = _container(storage);

    final state = container.read(historyViewModelProvider);
    expect(state.examRunning, isTrue);
    expect(state.entries.first.isRunning, isTrue);

    final opened = container
        .read(historyViewModelProvider.notifier)
        .openReport('old');

    expect(opened, isFalse);
    expect(container.read(sessionViewModelProvider)?.id, 'live');
  });

  test('refreshes when a new exam is saved', () async {
    final storage = _MemoryStorage();
    final container = _container(storage);
    expect(container.read(historyViewModelProvider).isEmpty, isTrue);

    final session = container.read(sessionViewModelProvider.notifier);
    await session.createSession(
      instituteName: 'X',
      teacherName: 'Y',
      roomNumber: '1',
    );
    await session.endCurrentSession();

    final state = container.read(historyViewModelProvider);
    expect(state.entries, hasLength(1));
    expect(state.examRunning, isFalse);
  });
}
