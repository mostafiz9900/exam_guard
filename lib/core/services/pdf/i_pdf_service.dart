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

/// One entry of a color legend, e.g. a filled swatch and `Critical`.
class PdfLegendItem {
  const PdfLegendItem(this.label, this.color);

  final String label;
  final Color color;
}

/// One marked grid cell. [color] fills/borders it; [text] is printed inside
/// (e.g. a count).
class PdfGridCell {
  const PdfGridCell({this.text = '', this.color});

  final String text;
  final Color? color;
}

/// A labelled [rows] × [columns] grid (e.g. a room's seat map). Unmarked
/// cells are drawn empty; [cells] marks some of them by `(row, column)`,
/// both zero-based.
class PdfGrid {
  const PdfGrid({
    required this.rows,
    required this.columns,
    this.rowLabels = const [],
    this.columnLabels = const [],
    this.cells = const {},
    this.topLabel,
    this.legend = const [],
    this.note,
  });

  final int rows;
  final int columns;

  /// Shown left of each row / above each column; missing labels are blank.
  final List<String> rowLabels;
  final List<String> columnLabels;

  final Map<(int, int), PdfGridCell> cells;

  /// Band drawn above the grid, e.g. `FRONT`.
  final String? topLabel;

  final List<PdfLegendItem> legend;

  /// Small muted line under the legend.
  final String? note;
}

/// An image to embed with a caption. Give either the encoded [bytes] (PNG or
/// JPEG) or a [path] to a file the service reads. Images that are missing or
/// cannot be decoded are skipped and listed with
/// [PdfTableDocument.imageMissingText].
class PdfImageItem {
  const PdfImageItem({this.path, this.bytes, required this.caption})
    : assert(path != null || bytes != null);

  final String? path;
  final Uint8List? bytes;
  final String caption;
}

/// Content of a structured report: header band, meta grid, summary boxes,
/// a multi-page table, signature blocks and a footer on every page.
/// One line on a [PdfChart]: values over time.
class PdfChartSeries {
  const PdfChartSeries({
    required this.label,
    required this.color,
    required this.points,
    this.breakAfter,
  });

  final String label;
  final Color color;
  final List<(DateTime, double)> points;

  /// A longer gap between two points breaks the line (no data there).
  final Duration? breakAfter;
}

/// A dashed horizontal reference line, e.g. "near" at -65 dBm.
class PdfChartLine {
  const PdfChartLine(this.value, this.label);

  final double value;
  final String label;
}

/// A small time chart: lines over shaded bands, with reference lines.
class PdfChart {
  const PdfChart({
    required this.title,
    required this.start,
    required this.end,
    required this.minY,
    required this.maxY,
    required this.series,
    required this.startLabel,
    required this.endLabel,
    this.subtitle,
    this.bands = const [],
    this.bandLabel,
    this.refLines = const [],
    this.note,
  });

  final String title;
  final String? subtitle;
  final DateTime start;
  final DateTime end;
  final double minY;
  final double maxY;
  final List<PdfChartSeries> series;

  /// Time axis labels under the chart.
  final String startLabel;
  final String endLabel;

  /// Shaded time spans (e.g. when a device was in range).
  final List<(DateTime, DateTime)> bands;
  final String? bandLabel;
  final List<PdfChartLine> refLines;

  /// Small print under the chart.
  final String? note;
}

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
    this.gridTitle,
    this.grid,
    this.overviewTitle,
    this.overviewCharts = const [],
    this.chartsTitle,
    this.charts = const [],
    this.imagesTitle,
    this.images = const [],
    this.imageMissingText = 'Image not available',
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

  /// Optional grid section (after the summary, before the table).
  final String? gridTitle;
  final PdfGrid? grid;

  /// Charts after the summary / grid (e.g. activity over the exam).
  final String? overviewTitle;
  final List<PdfChart> overviewCharts;

  /// Charts after the table (e.g. one per incident).
  final String? chartsTitle;
  final List<PdfChart> charts;

  /// Images with captions, two per row, after the table.
  final String? imagesTitle;
  final List<PdfImageItem> images;

  /// Prefix of the note listed for each image that could not be loaded,
  /// e.g. `Image not available: 10:02 · Seat C4`.
  final String imageMissingText;

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
