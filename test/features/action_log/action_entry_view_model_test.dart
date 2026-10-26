import 'dart:async';

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/action_log/view_model/action_entry_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
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

/// Hands out numbered photo paths and records deletions.
class _FakePhotoService implements IPhotoService {
  final deleted = <String>[];
  var taken = 0;
  Object? error;
  bool cancel = false;

  @override
  Future<String?> takePhoto() async {
    if (error != null) throw error!;
    if (cancel) return null;
    return '/photos/${++taken}.jpg';
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<bool> exists(String path) async => !deleted.contains(path);
}

void main() {
  late _GatedStorage storage;
  late _FakePhotoService photos;
  late ProviderContainer container;

  setUp(() async {
    storage = _GatedStorage();
    photos = _FakePhotoService();
    container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        photoServiceProvider.overrideWithValue(photos),
      ],
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

  test('evidence never starts the scanner just to read history', () async {
    final vm = container.read(actionEntryViewModelProvider.notifier);
    expect(vm.evidenceFor('AA:BB'), isNull);
    expect(container.exists(scannerViewModelProvider), isFalse);
    await save(vm);
    final log = container.read(sessionViewModelProvider)!.deviceLogs.single;
    expect(log.evidence, isNull);
  });

  group('validation', () {
    late ActionEntryViewModel vm;
    setUp(() => vm = container.read(actionEntryViewModelProvider.notifier));

    test('a seat alone is enough', () {
      expect(vm.validate(deviceName: '', location: '', seat: 'C4'), isNull);
    });

    test('a device name or a location note alone is enough', () {
      expect(vm.validate(deviceName: 'Phone', location: ''), isNull);
      expect(vm.validate(deviceName: ' ', location: 'Back row'), isNull);
    });

    test('nothing (or blanks) is rejected', () {
      expect(
        vm.validate(deviceName: ' ', location: '', seat: ' '),
        'incident_err_seat_name_or_location',
      );
      expect(
        vm.validate(deviceName: '', location: ''),
        'incident_err_seat_name_or_location',
      );
    });

    test('saving with only a seat stores the seat', () async {
      final result = await vm.save(
        deviceName: '',
        deviceId: '',
        category: 'Bluetooth Device',
        severity: LogSeverity.medium,
        location: '',
        notes: '',
        seat: 'c4',
      );
      expect(result.status, ActionSaveStatus.saved);
      expect(result.log?.seat, 'C4');
      expect(
        container.read(sessionViewModelProvider)?.deviceLogs.single.seat,
        'C4',
      );
    });
  });

  group('photos', () {
    late ActionEntryViewModel vm;
    setUp(() => vm = container.read(actionEntryViewModelProvider.notifier));

    test('taken photos are saved with the incident and not deleted', () async {
      expect(await vm.addPhoto(), isNull);
      expect(await vm.addPhoto(), isNull);
      final result = await save(vm);

      expect(result.log?.photoPaths, ['/photos/1.jpg', '/photos/2.jpg']);
      expect(
        container.read(sessionViewModelProvider)?.deviceLogs.single.photoPaths,
        hasLength(2),
      );
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(photos.deleted, isEmpty);
    });

    test('leaving without saving deletes every taken photo', () async {
      await vm.addPhoto();
      await vm.addPhoto();
      expect(vm.hasUnsavedPhotos, isTrue);

      container.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(
        photos.deleted,
        unorderedEquals(['/photos/1.jpg', '/photos/2.jpg']),
      );
    });

    test(
      'removing a photo deletes its file and drops it from the form',
      () async {
        await vm.addPhoto();
        await vm.addPhoto();
        await vm.removePhoto('/photos/1.jpg');

        expect(photos.deleted, ['/photos/1.jpg']);
        expect(container.read(actionEntryViewModelProvider).photoPaths, [
          '/photos/2.jpg',
        ]);
        final result = await save(vm);
        expect(result.log?.photoPaths, ['/photos/2.jpg']);
      },
    );

    test('a failed save keeps the photos for a retry', () async {
      await vm.addPhoto();
      storage.gate = Completer<void>()
        ..completeError(const StorageException('disk full'));
      final result = await save(vm);

      expect(result.status, ActionSaveStatus.failed);
      expect(vm.hasUnsavedPhotos, isTrue);
      expect(photos.deleted, isEmpty);
    });

    test('at most ${ActionEntryViewModel.maxPhotos} photos', () async {
      for (var i = 0; i < ActionEntryViewModel.maxPhotos; i++) {
        expect(await vm.addPhoto(), isNull);
      }
      expect(await vm.addPhoto(), 'incident_photo_limit');
      expect(
        container.read(actionEntryViewModelProvider).photoPaths,
        hasLength(ActionEntryViewModel.maxPhotos),
      );
      expect(container.read(actionEntryViewModelProvider).canAddPhoto, isFalse);
    });

    test('camera errors become a message; cancel adds nothing', () async {
      photos.error = const PhotoException('no camera');
      expect(await vm.addPhoto(), 'incident_photo_failed');

      photos
        ..error = null
        ..cancel = true;
      expect(await vm.addPhoto(), isNull);
      expect(container.read(actionEntryViewModelProvider).photoPaths, isEmpty);
      expect(
        container.read(actionEntryViewModelProvider).isTakingPhoto,
        isFalse,
      );
    });
  });
}
