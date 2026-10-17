import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/pdf/pdf_service_impl.dart';

/// Content of a simple tabular PDF document.
class PdfTableDocument {
  const PdfTableDocument({
    required this.title,
    this.infoRows = const {},
    this.summary,
    this.tableHeaders = const [],
    this.tableRows = const [],
    this.emptyTableText,
    this.closingText,
  });

  final String title;

  /// Label → value pairs shown under the title.
  final Map<String, String> infoRows;
  final String? summary;
  final List<String> tableHeaders;
  final List<List<String>> tableRows;

  /// Shown instead of the table when [tableRows] is empty.
  final String? emptyTableText;

  /// Shown at the end, e.g. a signature line.
  final String? closingText;
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
