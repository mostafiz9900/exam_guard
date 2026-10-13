import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/session/domain/session_model.dart';

/// Builds the end-of-exam session report as a PDF. Wraps the `pdf` package.
class SessionReportPdfService {
  Future<Uint8List> build(SessionModel session) async {
    final doc = pw.Document(
      title: 'ExamGuard Session Report',
      creator: 'ExamGuard',
    );
    final logs = session.deviceLogs;
    int count(String severity) =>
        logs.where((l) => l['severity'] == severity).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Text(
          'ExamGuard — Exam Security Session Report',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _infoTable({
            'Institute': session.instituteName,
            'Room': session.roomNumber,
            'Inspector': session.teacherName,
            'Started': _formatDateTime(session.startTime),
            'Ended': session.endTime == null
                ? 'In progress'
                : _formatDateTime(session.endTime!),
            'Duration': _formatDuration(
              (session.endTime ?? DateTime.now()).difference(session.startTime),
            ),
          }),
          pw.SizedBox(height: 16),
          pw.Text(
            'Incidents: ${logs.length}  ·  Critical: ${count('CRITICAL')}  ·  '
            'High: ${count('HIGH')}  ·  Medium: ${count('MEDIUM')}  ·  '
            'Low: ${count('LOW')}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (logs.isEmpty)
            pw.Text('No incidents were logged during this session.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Time',
                'Severity',
                'Device',
                'Device ID',
                'Location',
                'Notes',
              ],
              data: [
                for (final l in logs)
                  [
                    l['createdAt'] is int
                        ? _formatTime(
                            DateTime.fromMillisecondsSinceEpoch(
                              l['createdAt'] as int,
                            ),
                          )
                        : '',
                    '${l['severity'] ?? ''}',
                    '${l['name'] ?? ''}',
                    '${l['id'] ?? ''}',
                    '${l['location'] ?? ''}',
                    '${l['notes'] ?? ''}',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          pw.SizedBox(height: 32),
          pw.Text('Inspector signature: ______________________________'),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _infoTable(Map<String, String> rows) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(90),
        1: pw.FlexColumnWidth(),
      },
      children: [
        for (final e in rows.entries)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                  e.key,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(e.value.isEmpty ? '-' : e.value),
              ),
            ],
          ),
      ],
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  String _formatDateTime(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_formatTime(d)}';

  String _formatDuration(Duration d) =>
      '${d.inHours}h ${_two(d.inMinutes % 60)}m';
}

final sessionReportPdfServiceProvider = Provider<SessionReportPdfService>(
  (ref) => SessionReportPdfService(),
);
