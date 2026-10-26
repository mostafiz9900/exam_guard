import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/repository/session_repository.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class InMemoryStorage implements ILocalStorage {
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

void main() {
  test(
    'ending the exam records the end time and keeps the report data',
    () async {
      final storage = InMemoryStorage();
      final container = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(sessionViewModelProvider), isNull);
      final viewModel = container.read(sessionViewModelProvider.notifier);
      await viewModel.createSession(
        instituteName: 'Test School',
        teacherName: 'Inspector',
        roomNumber: '12',
      );
      await viewModel.addLog(
        ActionLogModel(
          deviceName: 'Phone',
          deviceId: 'AA:BB',
          category: 'Bluetooth Device',
          severity: LogSeverity.high,
          location: 'Desk 4',
          notes: '',
          createdAt: DateTime(2026, 10, 13, 10),
        ),
      );

      final ended = await viewModel.endCurrentSession();

      expect(ended?.endTime, isNotNull);
      expect(storage.read<String>('current_session_id'), isNull);

      // Logging after the exam ended is rejected.
      await expectLater(
        viewModel.addLog(
          ActionLogModel(
            deviceName: 'Late',
            deviceId: '',
            category: '',
            severity: LogSeverity.low,
            location: '',
            notes: '',
            createdAt: DateTime(2026),
          ),
        ),
        throwsA(isA<NoActiveSessionException>()),
      );

      // A fresh read from storage returns the same ended session and its log.
      final reloaded = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(reloaded.dispose);
      // The ended exam is no longer running, but its report is reachable.
      expect(reloaded.read(sessionViewModelProvider), isNull);
      final last = reloaded.read(sessionViewModelProvider.notifier).lastSession;
      expect(last?.deviceLogs.single.severity, LogSeverity.high);
      final all = reloaded.read(sessionRepositoryProvider).allSessions();
      expect(all.single.endTime, isNotNull);
      expect(all.single.deviceLogs.single.severity, LogSeverity.high);
    },
  );

  test('a corrupt session entry is skipped instead of crashing', () async {
    final storage = InMemoryStorage()
      ..values['current_session_id'] = 'bad'
      ..values['last_session_id'] = 'bad'
      // `id` missing and wrong types: SessionModel.fromJson throws.
      ..values['session_bad'] = <dynamic, dynamic>{
        'instituteName': 42,
        'startTime': 'x',
      };
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(container.read(sessionViewModelProvider), isNull);
    final repository = container.read(sessionRepositoryProvider);
    expect(repository.lastSession(), isNull);
    expect(repository.allSessions(), isEmpty);
  });

  test('pointer write failures do not fail the save', () async {
    final storage = _PointerFailingStorage();
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container
        .read(sessionViewModelProvider.notifier)
        .createSession(instituteName: 'S', teacherName: 'T', roomNumber: '1');

    expect(
      storage.values.keys.where((k) => k.startsWith('session_')),
      hasLength(1),
    );
    expect(container.read(sessionViewModelProvider)?.roomNumber, '1');
  });
}

/// Stores sessions but fails to write the pointer keys.
class _PointerFailingStorage extends InMemoryStorage {
  @override
  Future<void> write(String key, Object? value) async {
    if (key.endsWith('_session_id')) {
      throw const StorageException('disk full');
    }
    await super.write(key, value);
  }
}
