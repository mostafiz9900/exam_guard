import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exam_guard/core/services/pdf/pdf_service_impl.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

SessionModel _session(int incidents) {
  final start = DateTime(2026, 10, 13, 9);
  return SessionModel(
    id: '${start.millisecondsSinceEpoch}',
    instituteName: 'Dhaka College',
    teacherName: 'Rahim Uddin',
    roomNumber: '12/B',
    startTime: start,
    endTime: start.add(const Duration(hours: 3)),
    deviceLogs: [
      for (var i = 0; i < incidents; i++)
        ActionLogModel(
          deviceName: 'Device $i',
          deviceId: 'AA:BB:CC:DD:EE:${(i % 100).toString().padLeft(2, '0')}',
          category: i.isEven ? 'Phone' : 'Earbuds',
          severity: LogSeverity.values[i % LogSeverity.values.length],
          location: 'Desk ${i + 1}',
          notes: i % 5 == 0
              ? 'Long note that should wrap inside the notes column. ' * 4
              : 'Found under desk',
          createdAt: start.add(Duration(minutes: i * 3)),
        ),
    ],
  );
}

/// Counts page objects (`/Type /Page`, not `/Pages`) in an uncompressed
/// PDF object table.
int _pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page(?![s\w])')
        .allMatches(String.fromCharCodes(bytes))
        .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = PdfServiceImpl();

  Future<List<int>> build(SessionModel session, List<String> printed) =>
      runZoned(
        () => service.buildTableDocument(
          ReportRepository.buildDocument(
            session,
            generatedAt: DateTime(2026, 10, 13, 12, 5),
          ),
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

  test('report with no incidents builds a single page', () async {
    final printed = <String>[];
    final bytes = await build(_session(0), printed);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(_pageCount(bytes), 1);
    expect(printed.where((l) => l.contains('Unable to find a font')), isEmpty);
  });

  test('report with 40 incidents spans multiple pages', () async {
    final printed = <String>[];
    final bytes = await build(_session(40), printed);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(_pageCount(bytes), greaterThan(1));
    expect(printed.where((l) => l.contains('Unable to find a font')), isEmpty);
  });

  group('document content', () {
    test('summary, verdict and table follow the incidents', () {
      final doc = ReportRepository.buildDocument(_session(5));
      expect(doc.summaryItems.map((s) => s.label), [
        'Total',
        'Critical',
        'High',
        'Medium',
        'Low',
      ]);
      expect(doc.summaryItems.map((s) => s.value), ['5', '2', '1', '1', '1']);
      expect(doc.summaryText, '5 violations recorded — 2 critical');
      expect(doc.tableColumns.map((c) => c.label), contains('Category'));
      expect(doc.tableRows, hasLength(5));
      expect(doc.tableRows.first[1].color, isNotNull);
      expect(doc.signatures.map((s) => s.role), [
        'Invigilator',
        'Exam Controller',
      ]);
      expect(doc.signatures.first.name, 'Rahim Uddin');
    });

    test('empty session has a clear verdict', () {
      final doc = ReportRepository.buildDocument(_session(0));
      expect(doc.summaryText, 'No violations recorded');
      expect(doc.tableRows, isEmpty);
      expect(doc.emptyTableTitle, isNotNull);
    });

    test('report id is short and derived from the session id', () {
      final id = ReportRepository.reportId(_session(0));
      expect(id, startsWith('EG-'));
      expect(id.length, lessThanOrEqualTo(13));
    });
  });

  group('seat map, photos and baseline', () {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('report_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    SessionModel withEvidence({required bool filesExist}) {
      final base = _session(0);
      String photo(String name) {
        final path = '${dir.path}/$name';
        if (filesExist) File(path).writeAsBytesSync(png);
        return path;
      }

      ActionLogModel log(
        String? seat,
        LogSeverity severity,
        List<String> photos,
      ) => ActionLogModel(
        deviceName: 'AirPods',
        deviceId: 'AA',
        category: 'Classic Bluetooth Earpiece',
        severity: severity,
        location: '',
        notes: '',
        createdAt: base.startTime.add(const Duration(minutes: 5)),
        seat: seat,
        photoPaths: photos,
      );

      return base.copyWith(
        seatRows: 6,
        seatCols: 8,
        baselineAt: base.startTime.add(const Duration(minutes: 2)),
        trustedDeviceIds: {'X', 'Y', 'Z'},
        deviceLogs: [
          log('C4', LogSeverity.low, [photo('1.png'), photo('2.png')]),
          log('C4', LogSeverity.critical, const []),
          log('A1', LogSeverity.medium, [photo('3.png')]),
          log(null, LogSeverity.high, const []),
          log('Z99', LogSeverity.high, const []),
        ],
      );
    }

    test('document has seat column, seat grid, photos and baseline', () {
      final doc = ReportRepository.buildDocument(
        withEvidence(filesExist: true),
      );

      final seatCol = doc.tableColumns.indexWhere((c) => c.label == 'Seat');
      expect(seatCol, greaterThanOrEqualTo(0));
      expect(doc.tableRows.map((r) => r[seatCol].text), [
        'C4',
        'C4',
        'A1',
        '-',
        'Z99',
      ]);

      final grid = doc.grid!;
      expect((grid.rows, grid.columns), (6, 8));
      expect(grid.rowLabels.first, 'A');
      expect(grid.columnLabels.last, '8');
      expect(grid.cells.keys, unorderedEquals([(2, 3), (0, 0)]));
      expect(grid.cells[(2, 3)]!.text, '2');
      expect(
        grid.cells[(2, 3)]!.color,
        ReportRepository.severityColor(LogSeverity.critical),
      );
      expect(grid.note, contains('outside this layout'));

      expect(doc.images, hasLength(3));
      expect(doc.images.first.caption, contains('Seat C4'));
      expect(doc.images.first.caption, contains('AirPods'));
      expect(doc.images.first.caption, contains('photo 1 of 2'));

      final baseline = doc.metaRows.firstWhere((m) => m.label == 'Baseline');
      expect(baseline.value, contains('3 trusted devices'));
    });

    test('no layout → no grid; no baseline is stated', () {
      final doc = ReportRepository.buildDocument(_session(2));
      expect(doc.grid, isNull);
      expect(doc.images, isEmpty);
      expect(
        doc.metaRows.firstWhere((m) => m.label == 'Baseline').value,
        'No baseline was taken',
      );
    });

    for (final filesExist in [true, false]) {
      test('PDF builds with seat map and '
          '${filesExist ? 'photos' : 'missing photo files'}', () async {
        final printed = <String>[];
        final bytes = await build(
          withEvidence(filesExist: filesExist),
          printed,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(
          printed.where((l) => l.contains('Unable to find a font')),
          isEmpty,
        );
        final images = RegExp(r'/Subtype\s*/Image')
            .allMatches(String.fromCharCodes(bytes))
            .length;
        expect(images > 0, filesExist);
      });
    }
  });
}
