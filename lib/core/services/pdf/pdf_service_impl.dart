import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';

class PdfServiceImpl implements IPdfService {
  @override
  Future<Uint8List> buildTableDocument(PdfTableDocument document) async {
    final doc = pw.Document(title: document.title, creator: 'ExamGuard');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Text(
          document.title,
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
          if (document.infoRows.isNotEmpty) _infoTable(document.infoRows),
          if (document.summary != null) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              document.summary!,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
          pw.SizedBox(height: 12),
          if (document.tableRows.isEmpty && document.emptyTableText != null)
            pw.Text(document.emptyTableText!)
          else if (document.tableRows.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: document.tableHeaders,
              data: document.tableRows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          if (document.closingText != null) ...[
            pw.SizedBox(height: 32),
            pw.Text(document.closingText!),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _infoTable(Map<String, String> rows) {
    return pw.Table(
      columnWidths: const {0: pw.FixedColumnWidth(90), 1: pw.FlexColumnWidth()},
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
}
