import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/pdf/pdf_service_impl.dart';

/// A label → value pair, e.g. `Room: 12/B`.
class PdfMetaItem {
  const PdfMetaItem(this.label, this.value);

  final String label;
  final String value;
}

/// One small box in the summary row, e.g. `Critical 3`. [color] tints the
/// value and the box accent; null uses the neutral text color.
class PdfSummaryItem {
  const PdfSummaryItem({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;
}

/// A table column. [flex] sets its share of the table width.
class PdfTableColumn {
  const PdfTableColumn(this.label, {this.flex = 1});

  final String label;
  final double flex;
}

/// One table cell. A [color] renders the cell as an outlined badge in that
/// color (e.g. a severity), otherwise it is plain text.
class PdfTableCell {
  const PdfTableCell(this.text, {this.color, this.bold = false});

  final String text;
  final Color? color;
  final bool bold;
}

/// A signature block: [role] heading, a signature line, then name and date
/// lines. [name] is prefilled when given, otherwise left blank to write in.
class PdfSignatureBlock {
  const PdfSignatureBlock({required this.role, this.name});

  final String role;
  final String? name;
}

/// Content of a structured report: header band, meta grid, summary boxes,
/// a multi-page table, signature blocks and a footer on every page.
class PdfTableDocument {
  const PdfTableDocument({
    required this.title,
    this.brand,
    this.headerMeta = const [],
    this.metaTitle,
    this.metaRows = const [],
    this.summaryTitle,
    this.summaryItems = const [],
    this.summaryText,
    this.summaryColor,
    this.tableTitle,
    this.tableColumns = const [],
    this.tableRows = const [],
    this.emptyTableTitle,
    this.emptyTableText,
    this.signatures = const [],
    this.footerText,
  });

  /// Document title, shown in the header band and the PDF metadata.
  final String title;

  /// Wordmark shown above the title, e.g. the app name.
  final String? brand;

  /// Small label → value lines on the right of the header band.
  final List<PdfMetaItem> headerMeta;

  final String? metaTitle;

  /// Shown as a bordered grid, two pairs per row.
  final List<PdfMetaItem> metaRows;

  final String? summaryTitle;
  final List<PdfSummaryItem> summaryItems;

  /// Verdict line under the summary boxes, accented with [summaryColor].
  final String? summaryText;
  final Color? summaryColor;

  final String? tableTitle;
  final List<PdfTableColumn> tableColumns;

  /// Each row has one cell per column. The header repeats on every page.
  final List<List<PdfTableCell>> tableRows;

  /// Shown in a framed box instead of the table when [tableRows] is empty.
  final String? emptyTableTitle;
  final String? emptyTableText;

  /// Shown side by side at the end of the document.
  final List<PdfSignatureBlock> signatures;

  /// Left side of every page footer; the right side is `Page X of Y`.
  final String? footerText;
}

/// Thrown when a PDF could not be generated. The cause is logged.
class PdfGenerationException implements Exception {
  const PdfGenerationException(this.cause);

  final Object cause;

  @override
  String toString() => 'PdfGenerationException: $cause';
}

/// PDF generation. Features use this instead of the `pdf` package.
abstract interface class IPdfService {
  /// Throws [PdfGenerationException] on failure.
  Future<Uint8List> buildTableDocument(PdfTableDocument document);
}

/// Kept alive for the app's lifetime so the bundled fonts load only once.
final pdfServiceProvider = Provider<IPdfService>(
  (ref) => PdfServiceImpl(logger: ref.watch(appLoggerProvider)),
);
