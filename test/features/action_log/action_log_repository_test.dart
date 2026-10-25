import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/action_log/repository/action_log_repository.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _FakeShare implements IShareService {
  final texts = <(String, String?, Rect?)>[];
  ShareOutcome outcome = ShareOutcome.shared;
  Object? error;

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    if (error != null) throw error!;
    texts.add((text, subject, origin));
    return outcome;
  }

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  }) async => throw UnimplementedError();
}

class _FakePhotos implements IPhotoService {
  String? next = '/photos/1.jpg';
  Object? error;
  final deleted = <String>[];

  @override
  Future<String?> takePhoto() async {
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<bool> exists(String path) async => true;
}

final _at = DateTime(2026, 10, 13, 15, 45, 12);

ActionLogModel _log({
  String name = 'Galaxy Buds',
  String id = 'AA:BB',
  String category = 'Bluetooth Device',
  LogSeverity severity = LogSeverity.high,
  String location = 'Row 2',
  String notes = 'In pocket',
  String? seat = 'B3',
  List<String> photos = const [],
}) => ActionLogModel(
  deviceName: name,
  deviceId: id,
  category: category,
  severity: severity,
  location: location,
  notes: notes,
  createdAt: _at,
  seat: seat,
  photoPaths: photos,
);

final _session = SessionModel(
  id: 's1',
  instituteName: 'Dhaka College',
  teacherName: 'Mr. Rahman',
  roomNumber: '302-B',
  startTime: _at,
);

/// The value printed after "Label : " on the report line starting with [label].
String _field(String report, String label) {
  final line = report.split('\n').firstWhere((l) => l.startsWith(label));
  return line.substring(line.indexOf(':') + 1).trim();
}

void main() {
  late _FakeShare share;
  late _FakePhotos photos;
  late ActionLogRepository repo;

  setUp(() {
    share = _FakeShare();
    photos = _FakePhotos();
    repo = ActionLogRepository(share, photos);
  });

  group('photos', () {
    test('takePhoto returns the saved path', () async {
      expect(await repo.takePhoto(), '/photos/1.jpg');
    });

    test('takePhoto returns null when the user cancels', () async {
      photos.next = null;
      expect(await repo.takePhoto(), isNull);
    });

    test('takePhoto passes PhotoException through', () {
      photos.error = const PhotoException('no camera');
      expect(repo.takePhoto(), throwsA(isA<PhotoException>()));
    });

    test('deletePhoto deletes through the photo service', () async {
      await repo.deletePhoto('/photos/1.jpg');
      expect(photos.deleted, ['/photos/1.jpg']);
    });
  });

  group('buildTextReport', () {
    test('fills every field from the log, session and scanned device', () {
      final device = ScannedDeviceModel(
        id: 'AA:BB',
        name: 'Buds',
        manufacturer: 'Samsung Electronics',
        rssi: -58,
        lastSeen: _at,
        firstSeen: _at,
      );
      final report = repo.buildTextReport(
        log: _log(photos: const ['/a.jpg', '/b.jpg']),
        session: _session,
        scannedDevice: device,
      );

      expect(report, contains('OFFICIAL EXAM SECURITY VIOLATION REPORT'));
      expect(_field(report, 'Incident Logged At'), '2026-10-13 03:45:12 PM');
      expect(_field(report, 'Institute / Center'), 'Dhaka College');
      expect(_field(report, 'Exam Room / Hall'), '302-B');
      expect(_field(report, 'Inspector In-Charge'), 'Mr. Rahman');
      expect(_field(report, 'Candidate Seat No.'), 'B3');
      expect(_field(report, 'Location Note'), 'Row 2');
      expect(_field(report, 'Category'), 'Bluetooth Device');
      expect(_field(report, 'Severity'), 'HIGH');
      expect(_field(report, 'Device Name'), 'Galaxy Buds');
      expect(_field(report, 'Device ID'), 'AA:BB');
      expect(_field(report, 'Hardware Vendor'), 'Samsung Electronics');
      expect(_field(report, 'Last RSSI'), '-58 dBm');
      expect(_field(report, 'Evidence Photos'), '2 attached');
      expect(
        report,
        contains(
          '[INSPECTOR NOTES]\n'
          '-----------------------------------------------------------------\n'
          'In pocket\n',
        ),
      );
      expect(_field(report, 'Date'), '2026-10-13 03:45:12 PM');
    });

    test('uses "-" for missing values and "None" without photos', () {
      final report = repo.buildTextReport(
        log: _log(
          name: '',
          id: '',
          category: '',
          location: '',
          notes: '',
          seat: null,
        ),
        session: null,
      );

      for (final label in [
        'Institute / Center',
        'Exam Room / Hall',
        'Inspector In-Charge',
        'Candidate Seat No.',
        'Location Note',
        'Category',
        'Device Name',
        'Device ID',
        'Hardware Vendor',
        'Last RSSI',
      ]) {
        expect(_field(report, label), '-', reason: label);
      }
      expect(_field(report, 'Evidence Photos'), 'None');
      expect(
        report,
        contains(
          '[INSPECTOR NOTES]\n'
          '-----------------------------------------------------------------\n'
          '-\n',
        ),
      );
    });

    test('empty seat and session fields also become "-"', () {
      final report = repo.buildTextReport(
        log: _log(seat: ''),
        session: _session.copyWith(instituteName: '', teacherName: ''),
      );
      expect(_field(report, 'Candidate Seat No.'), '-');
      expect(_field(report, 'Institute / Center'), '-');
      expect(_field(report, 'Inspector In-Charge'), '-');
      expect(_field(report, 'Exam Room / Hall'), '302-B');
    });

    test('prints each severity code', () {
      for (final severity in LogSeverity.values) {
        final report = repo.buildTextReport(
          log: _log(severity: severity),
          session: _session,
        );
        expect(_field(report, 'Severity'), severity.code);
      }
    });

    test('one photo reads "1 attached"', () {
      final report = repo.buildTextReport(
        log: _log(photos: const ['/a.jpg']),
        session: _session,
      );
      expect(_field(report, 'Evidence Photos'), '1 attached');
    });
  });

  group('shareReport', () {
    test('shares the text with subject and origin', () async {
      const origin = Rect.fromLTWH(1, 2, 3, 4);
      final outcome = await repo.shareReport(
        'report',
        subject: 'Incident',
        origin: origin,
      );
      expect(outcome, ShareOutcome.shared);
      expect(share.texts.single, ('report', 'Incident', origin));
    });

    test('returns the share sheet outcome', () async {
      share.outcome = ShareOutcome.dismissed;
      expect(await repo.shareReport('r', subject: 's'), ShareOutcome.dismissed);
      share.outcome = ShareOutcome.unavailable;
      expect(
        await repo.shareReport('r', subject: 's'),
        ShareOutcome.unavailable,
      );
    });

    test('passes share failures through', () {
      share.error = const ShareFailedException('boom');
      expect(
        repo.shareReport('r', subject: 's'),
        throwsA(isA<ShareFailedException>()),
      );
    });
  });

  test(
    'provider builds the repository from the share and photo services',
    () async {
      final container = ProviderContainer(
        overrides: [
          shareServiceProvider.overrideWithValue(share),
          photoServiceProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(container.dispose);

      final fromProvider = container.read(actionLogRepositoryProvider);
      await fromProvider.deletePhoto('/x.jpg');
      await fromProvider.shareReport('t', subject: 's');
      expect(photos.deleted, ['/x.jpg']);
      expect(share.texts.single.$1, 't');
    },
  );
}
