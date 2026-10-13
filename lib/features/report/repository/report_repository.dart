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

  Future<ShareOutcome> exportSessionPdf(SessionModel session) async {
    final bytes = await _pdf.buildTableDocument(_document(session));
    return _share.shareFile(
      bytes: bytes,
      fileName:
          'examguard_room_${session.roomNumber}_${AppDateFormat.date(session.startTime)}.pdf',
      mimeType: 'application/pdf',
      subject: 'ExamGuard report — Room ${session.roomNumber}',
    );
  }

  PdfTableDocument _document(SessionModel session) {
    final logs = session.deviceLogs;
    int count(LogSeverity s) => logs.where((l) => l.severity == s).length;
    final duration = (session.endTime ?? DateTime.now()).difference(
      session.startTime,
    );

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
        'Duration':
            '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m',
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
            l.deviceName,
            l.deviceId,
            l.location,
            l.notes,
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
