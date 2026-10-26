// Report evidence: incident signal traces and exam activity, in the data
// model, the chart builders and a real generated PDF.

import 'dart:async';

import 'package:exam_guard/core/services/pdf/pdf_service_impl.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/activity_sample.dart';
import 'package:exam_guard/features/session/model/incident_evidence.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 26, 9);
DateTime _at(int s) => _t0.add(Duration(seconds: s));

IncidentEvidence _evidence() => IncidentEvidence(
  trace: [
    for (var s = 0; s <= 300; s += 5) EvidencePoint(_at(s), -70 + s ~/ 20),
  ],
  spans: [EvidenceSpan(_at(0), _at(120)), EvidenceSpan(_at(180), _at(300))],
  firstSeen: _at(0),
  peakRssi: -55,
  reappearances: 1,
  timePresent: const Duration(minutes: 4),
);

ActionLogModel _log({IncidentEvidence? evidence}) => ActionLogModel(
  deviceName: 'TWS Earbud',
  deviceId: 'AA:01',
  category: 'Bluetooth Device',
  severity: LogSeverity.high,
  location: 'Back row',
  notes: '',
  createdAt: _at(305),
  seat: 'C4',
  evidence: evidence,
);

SessionModel _session({
  List<ActionLogModel> logs = const [],
  bool activity = true,
}) => SessionModel(
  id: 's1',
  instituteName: 'School',
  teacherName: 'Rahim',
  roomNumber: '302-B',
  startTime: _t0,
  endTime: _t0.add(const Duration(hours: 1)),
  deviceLogs: logs,
  activity: [
    if (activity)
      for (var m = 0; m <= 60; m += 1)
        ActivitySample(
          at: _t0.add(Duration(minutes: m)),
          devices: 4 + (m % 7),
          untrusted: m % 3,
          alerts: m ~/ 20,
        ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('evidence survives storage; incidents without it still load', () {
    final log = _log(evidence: _evidence());
    final back = ActionLogModel.fromJson(log.toJson());
    final e = back.evidence!;
    expect(e.trace, hasLength(61));
    expect(e.trace.first.rssi, -70);
    expect(e.spans, hasLength(2));
    expect(e.peakRssi, -55);
    expect(e.timePresent, const Duration(minutes: 4));
    expect(ActionLogModel.fromJson(_log().toJson()).evidence, isNull);
  });

  test('evidence chart: device, seat, peak, bands and range', () {
    final c = ReportRepository.evidenceChart(_log(evidence: _evidence()))!;
    expect(c.title, contains('TWS Earbud'));
    expect(c.title, contains('Seat C4'));
    expect(c.subtitle, contains('-55 dBm'));
    expect(c.bands, hasLength(2));
    expect((c.minY, c.maxY), (-100, -30));
    expect(c.end, _at(305));
    expect(ReportRepository.evidenceChart(_log()), isNull);
  });

  test('activity chart needs two samples', () {
    expect(ReportRepository.activityChart(_session()), isNotNull);
    expect(ReportRepository.activityChart(_session(activity: false)), isNull);
  });

  test('a real PDF with activity and evidence charts is generated', () async {
    final printed = <String>[];
    final doc = ReportRepository.buildDocument(
      _session(
        logs: [
          _log(evidence: _evidence()),
          _log(),
        ],
      ),
      generatedAt: _t0,
    );
    expect(doc.overviewCharts, hasLength(1));
    expect(doc.charts, hasLength(1), reason: 'only the incident with evidence');
    final bytes = await runZoned(
      () => PdfServiceImpl().buildTableDocument(doc),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(printed.where((l) => l.contains('Unable to find a font')), isEmpty);
  });
}
