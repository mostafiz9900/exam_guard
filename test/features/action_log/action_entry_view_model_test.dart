import 'dart:async';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/action_log/view_model/action_entry_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../session_provider_test.dart' show InMemoryStorage;

/// Session writes wait for [gate] once it is set.
class _GatedStorage extends InMemoryStorage {
  Completer<void>? gate;

  @override
  Future<void> write(String key, Object? value) async {
    await gate?.future;
    await super.write(key, value);
  }
}

void main() {
  late _GatedStorage storage;
  late ProviderContainer container;

  setUp(() async {
    storage = _GatedStorage();
    container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    // Keep the autoDispose view model alive for the test.
    container.listen(actionEntryViewModelProvider, (_, _) {});
    await container
        .read(sessionViewModelProvider.notifier)
        .createSession(instituteName: 'S', teacherName: 'T', roomNumber: '1');
  });

  tearDown(() => container.dispose());

  Future<ActionSaveResult> save(ActionEntryViewModel vm) => vm.save(
    deviceName: 'Phone',
    deviceId: 'AA:BB',
    category: 'Magnetic Anomaly',
    severity: LogSeverity.high,
    location: 'Desk 4',
    notes: 'Under the desk',
  );

  test('a second save while one is in progress does nothing', () async {
    final vm = container.read(actionEntryViewModelProvider.notifier);
    storage.gate = Completer<void>();

    final first = save(vm);
    final second = await save(vm);
    expect(second.status, ActionSaveStatus.busy);

    storage.gate!.complete();
    final saved = await first;
    expect(saved.status, ActionSaveStatus.saved);
    expect(saved.log?.category, 'Magnetic Anomaly');
    expect(container.read(sessionViewModelProvider)?.deviceLogs, hasLength(1));
  });

  test('saving after the exam ended reports that, not a retry', () async {
    await container.read(sessionViewModelProvider.notifier).endCurrentSession();
    final vm = container.read(actionEntryViewModelProvider.notifier);

    final result = await save(vm);

    expect(result.status, ActionSaveStatus.sessionEnded);
    expect(result.message, 'incident_err_session_ended');
    expect(result.isSaved, isFalse);
  });

  test('an incomplete form is not saved', () async {
    final vm = container.read(actionEntryViewModelProvider.notifier);
    final result = await vm.save(
      deviceName: ' ',
      deviceId: '',
      category: 'Bluetooth Device',
      severity: LogSeverity.low,
      location: '',
      notes: '',
    );
    expect(result.status, ActionSaveStatus.invalid);
    expect(container.read(sessionViewModelProvider)?.deviceLogs, isEmpty);
  });

  test('a storage failure is reported generically', () async {
    final vm = container.read(actionEntryViewModelProvider.notifier);
    storage.gate = Completer<void>()
      ..completeError(const StorageException('disk full'));

    final result = await save(vm);

    expect(result.status, ActionSaveStatus.failed);
    expect(result.message, isNot(contains('disk full')));
  });
}
