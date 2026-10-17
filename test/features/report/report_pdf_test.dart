import 'dart:async';

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
}
