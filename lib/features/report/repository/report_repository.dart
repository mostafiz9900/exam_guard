import 'dart:ui' show Color, Rect;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Builds the end-of-exam session report and hands it to the share sheet.
class ReportRepository {
  ReportRepository(this._pdf, this._share);

  final IPdfService _pdf;
  final IShareService _share;

  Future<ShareOutcome> exportSessionPdf(
    SessionModel session, {
    Rect? origin,
  }) async {
    final bytes = await _pdf.buildTableDocument(buildDocument(session));
    return _share.shareFile(
      bytes: bytes,
      fileName: reportFileName(session),
      mimeType: 'application/pdf',
      subject: 'ExamGuard report — Room ${_orDash(session.roomNumber)}',
      origin: origin,
    );
  }

  /// e.g. `examguard_room_12_B_2026-10-13.pdf` for room "12/B".
  static String reportFileName(SessionModel session) => safeFileName(
    'examguard_room_${session.roomNumber}_${AppDateFormat.date(session.startTime)}.pdf',
  );

  static String _orDash(String v) => v.trim().isEmpty ? '-' : v;

  // Muted, print-friendly severity colors.
  static const _critical = Color(0xFFB42318);
  static const _high = Color(0xFFC4500C);
  static const _medium = Color(0xFF9A6700);
  static const _low = Color(0xFF3F6E8C);
  static const _clear = Color(0xFF2E7D4F);

  static Color severityColor(LogSeverity s) => switch (s) {
    LogSeverity.critical => _critical,
    LogSeverity.high => _high,
    LogSeverity.medium => _medium,
    LogSeverity.low => _low,
  };

  /// Short, human-readable report ID derived from the session id,
  /// e.g. `EG-MGO3K2F4` for a millisecond timestamp id.
  static String reportId(SessionModel session) {
    final millis = int.tryParse(session.id);
    final core = millis != null
        ? millis.toRadixString(36).toUpperCase()
        : session.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final short = core.length > 10 ? core.substring(core.length - 10) : core;
    return 'EG-${short.isEmpty ? '0' : short}';
  }

  /// e.g. "No violations recorded", "3 violations recorded — 1 critical".
  static String verdict(List<ActionLogModel> logs) {
    if (logs.isEmpty) return 'No violations recorded';
    final critical = logs.where((l) => l.severity == LogSeverity.critical);
    final noun = logs.length == 1 ? 'violation' : 'violations';
    return '${logs.length} $noun recorded — ${critical.length} critical';
  }

  /// e.g. "Taken 09:12:03 AM · 5 trusted devices" or "No baseline was taken".
  static String baselineText(SessionModel session) {
    final at = session.baselineAt;
    if (at == null) return 'No baseline was taken';
    final n = session.trustedDeviceIds.length;
    return 'Taken ${AppDateFormat.clock(at)} · $n trusted '
        '${n == 1 ? 'device' : 'devices'}';
  }

  /// Seat map of the room with seats colored by their highest severity,
  /// or null when the session has no layout.
  static PdfGrid? seatGrid(SessionModel session) {
    if (!session.hasSeatLayout) return null;
    final rows = session.seatRows!;
    final cols = session.seatCols!;
    final cells = <(int, int), PdfGridCell>{};
    var outside = 0;
    for (final MapEntry(key: seat, value: summary) in summarizeSeats(
      session.deviceLogs,
    ).entries) {
      final pos = SeatId.parse(seat);
      if (pos == null || pos.$1 >= rows || pos.$2 >= cols) {
        outside++;
        continue;
      }
      cells[pos] = PdfGridCell(
        text: '${summary.count}',
        color: severityColor(summary.highestSeverity),
      );
    }
    return PdfGrid(
      rows: rows,
      columns: cols,
      rowLabels: [for (var r = 0; r < rows; r++) SeatId.rowLabel(r)],
      columnLabels: [for (var c = 0; c < cols; c++) SeatId.colLabel(c)],
      cells: cells,
      topLabel: 'FRONT — Invigilator desk',
      legend: [
        for (final s in LogSeverity.values)
          PdfLegendItem(_titleCase(s.code), severityColor(s)),
      ],
      note:
          'Number in a seat = incidents recorded there; color = highest '
          'severity.${outside > 0 ? ' $outside seat(s) outside this layout '
                    'are listed in the incident log only.' : ''}',
    );
  }

  /// Every evidence photo, captioned with time, seat and device.
  static List<PdfImageItem> evidencePhotos(List<ActionLogModel> logs) => [
    for (final l in logs)
      for (var i = 0; i < l.photoPaths.length; i++)
        PdfImageItem(
          path: l.photoPaths[i],
          caption: [
            AppDateFormat.clock(l.createdAt),
            if ((l.seat ?? '').trim().isNotEmpty) 'Seat ${l.seat}',
            _orDash(l.deviceName),
            if (l.photoPaths.length > 1)
              'photo ${i + 1} of ${l.photoPaths.length}',
          ].join(' · '),
        ),
  ];

  /// Builds the report content. [generatedAt] defaults to now.
  @visibleForTesting
  static PdfTableDocument buildDocument(
    SessionModel session, {
    DateTime? generatedAt,
  }) {
    final logs = session.deviceLogs;
    final generated = AppDateFormat.fullDateTime(generatedAt ?? DateTime.now());
    int count(LogSeverity s) => logs.where((l) => l.severity == s).length;
    final criticalCount = count(LogSeverity.critical);

    return PdfTableDocument(
      brand: 'ExamGuard',
      title: 'Exam Security Session Report',
      headerMeta: [
        PdfMetaItem('Generated', generated),
        PdfMetaItem('Report ID', reportId(session)),
      ],
      metaTitle: 'Session details',
      metaRows: [
        PdfMetaItem('Institute', session.instituteName),
        PdfMetaItem('Room', session.roomNumber),
        PdfMetaItem('Inspector', session.teacherName),
        PdfMetaItem('Duration', AppDateFormat.duration(session.duration)),
        PdfMetaItem('Started', AppDateFormat.fullDateTime(session.startTime)),
        PdfMetaItem(
          'Ended',
          session.endTime == null
              ? 'In progress'
              : AppDateFormat.fullDateTime(session.endTime!),
        ),
        PdfMetaItem('Baseline', baselineText(session)),
        PdfMetaItem(
          'Seat layout',
          session.hasSeatLayout
              ? '${session.seatRows} rows × ${session.seatCols} seats'
              : 'Not set',
        ),
      ],
      summaryTitle: 'Summary',
      summaryItems: [
        PdfSummaryItem(label: 'Total', value: '${logs.length}'),
        for (final s in LogSeverity.values)
          PdfSummaryItem(
            label: _titleCase(s.code),
            value: '${count(s)}',
            color: severityColor(s),
          ),
      ],
      summaryText: verdict(logs),
      summaryColor: logs.isEmpty
          ? _clear
          : criticalCount > 0
          ? _critical
          : _high,
      gridTitle: 'Seat map',
      grid: seatGrid(session),
      tableTitle: 'Incident log',
      tableColumns: const [
        PdfTableColumn('Time', flex: 1.2),
        PdfTableColumn('Severity', flex: 1.15),
        PdfTableColumn('Category', flex: 1.2),
        PdfTableColumn('Device', flex: 1.5),
        PdfTableColumn('Device ID', flex: 1.7),
        PdfTableColumn('Seat', flex: 0.7),
        PdfTableColumn('Location', flex: 1.1),
        PdfTableColumn('Notes', flex: 2.3),
      ],
      tableRows: [
        for (final l in logs)
          [
            PdfTableCell(AppDateFormat.clock(l.createdAt)),
            PdfTableCell(l.severity.code, color: severityColor(l.severity)),
            PdfTableCell(_orDash(l.category)),
            PdfTableCell(_orDash(l.deviceName), bold: true),
            PdfTableCell(_orDash(l.deviceId)),
            PdfTableCell(_orDash(l.seat ?? ''), bold: true),
            PdfTableCell(_orDash(l.location)),
            PdfTableCell(_orDash(l.notes)),
          ],
      ],
      emptyTableTitle: 'No incidents were logged during this session.',
      emptyTableText:
          'The invigilator recorded no device violations between the start '
          'and end of this session.',
      imagesTitle: 'Evidence photos',
      images: evidencePhotos(logs),
      imageMissingText: 'Photo file missing (not included)',
      signatures: [
        PdfSignatureBlock(role: 'Invigilator', name: session.teacherName),
        const PdfSignatureBlock(role: 'Exam Controller'),
      ],
      footerText: 'Generated by ExamGuard · $generated',
    );
  }

  static String _titleCase(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(
    ref.watch(pdfServiceProvider),
    ref.watch(shareServiceProvider),
  ),
);
