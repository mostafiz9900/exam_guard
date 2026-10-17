import 'dart:ui' show Rect;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
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
    final bytes = await _pdf.buildTableDocument(_document(session));
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

  PdfTableDocument _document(SessionModel session) {
    final logs = session.deviceLogs;
    int count(LogSeverity s) => logs.where((l) => l.severity == s).length;

    return PdfTableDocument(
      title: 'ExamGuard — Exam Security Session Report',
      infoRows: {
        'Institute': session.instituteName,
        'Room': session.roomNumber,
        'Inspector': session.teacherName,
        'Started': AppDateFormat.fullDateTime(session.startTime),
        'Ended': session.endTime == null
            ? 'In progress'
            : AppDateFormat.fullDateTime(session.endTime!),
        'Duration': AppDateFormat.duration(session.duration),
      },
      summary:
          'Incidents: ${logs.length}  ·  '
          'Critical: ${count(LogSeverity.critical)}  ·  '
          'High: ${count(LogSeverity.high)}  ·  '
          'Medium: ${count(LogSeverity.medium)}  ·  '
          'Low: ${count(LogSeverity.low)}',
      tableHeaders: const [
        'Time',
        'Severity',
        'Device',
        'Device ID',
        'Location',
        'Notes',
      ],
      tableRows: [
        for (final l in logs)
          [
            AppDateFormat.clock(l.createdAt),
            l.severity.code,
            _orDash(l.deviceName),
            _orDash(l.deviceId),
            _orDash(l.location),
            _orDash(l.notes),
          ],
      ],
      emptyTableText: 'No incidents were logged during this session.',
      closingText: 'Inspector signature: ______________________________',
    );
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(
    ref.watch(pdfServiceProvider),
    ref.watch(shareServiceProvider),
  ),
);
