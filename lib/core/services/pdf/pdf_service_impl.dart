import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';

/// Loads a bundled asset. Replaceable in tests.
typedef PdfAssetLoader = Future<ByteData> Function(String key);

class PdfServiceImpl implements IPdfService {
  PdfServiceImpl({AppLogger? logger, PdfAssetLoader? loadAsset})
    : _logger = logger, // ignore: prefer_initializing_formals
      _loadAsset = loadAsset ?? rootBundle.load;

  static const _fontDir = 'assets/fonts';

  final AppLogger? _logger;
  final PdfAssetLoader _loadAsset;

  /// Loaded once and reused for every report.
  Future<_PdfFonts>? _fonts;

  // Arabic, Arabic Supplement, Arabic Extended-A, Presentation Forms A/B.
  static final _arabic = RegExp('[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');
  static final _bengali = RegExp('[ঀ-৿]');

  @override
  Future<Uint8List> buildTableDocument(PdfTableDocument document) async {
    try {
      final fonts = await _loadFonts();
      return await _build(document, fonts);
    } catch (e, st) {
      _logger?.error('Building PDF document failed', e, st);
      throw PdfGenerationException(e);
    }
  }

  Future<_PdfFonts> _loadFonts() {
    final cached = _fonts;
    if (cached != null) return cached;
    final loading = _PdfFonts.load(
      (name) async => pw.Font.ttf(await _loadAsset('$_fontDir/$name')),
    );
    _fonts = loading;
    // Allow a retry on the next export if loading failed.
    loading.then<void>((_) {}, onError: (Object _) => _fonts = null);
    return loading;
  }

  Future<Uint8List> _build(PdfTableDocument document, _PdfFonts fonts) {
    final doc = pw.Document(title: document.title, creator: 'ExamGuard');

    pw.Widget text(String value, {bool bold = false, double? fontSize}) =>
        _text(value, fonts, bold: bold, fontSize: fontSize);

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.bold,
          fontFallback: [fonts.bengali, fonts.arabic],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => text(document.title, bold: true, fontSize: 16),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          if (document.infoRows.isNotEmpty) _infoTable(document.infoRows, text),
          if (document.summary != null) ...[
            pw.SizedBox(height: 16),
            text(document.summary!, bold: true),
          ],
          pw.SizedBox(height: 12),
          if (document.tableRows.isEmpty && document.emptyTableText != null)
            text(document.emptyTableText!)
          else if (document.tableRows.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: [
                for (final h in document.tableHeaders)
                  text(h, bold: true, fontSize: 9),
              ],
              data: [
                for (final row in document.tableRows)
                  [for (final cell in row) text(cell, fontSize: 9)],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          if (document.closingText != null) ...[
            pw.SizedBox(height: 32),
            text(document.closingText!),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// A text widget whose font and direction follow its script: Arabic text is
  /// shaped right-to-left, Bengali text uses the Bengali font as primary so
  /// its characters stay in one run instead of glyph-by-glyph fallback.
  pw.Widget _text(
    String value,
    _PdfFonts fonts, {
    bool bold = false,
    double? fontSize,
  }) {
    final isArabic = _arabic.hasMatch(value);
    final isBengali = !isArabic && _bengali.hasMatch(value);
    final latin = bold ? fonts.bold : fonts.base;

    pw.Font? primary;
    var fallback = <pw.Font>[];
    if (isArabic) {
      primary = fonts.arabic;
      fallback = [latin, fonts.bengali];
    } else if (isBengali) {
      primary = bold ? fonts.bengaliBold : fonts.bengali;
      fallback = [latin, fonts.arabic];
    }

    return pw.Text(
      value,
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : null,
        font: primary,
        fontNormal: primary,
        fontBold: primary,
        fontFallback: fallback,
      ),
    );
  }

  pw.Widget _infoTable(
    Map<String, String> rows,
    pw.Widget Function(String value, {bool bold, double? fontSize}) text,
  ) {
    return pw.Table(
      columnWidths: const {0: pw.FixedColumnWidth(90), 1: pw.FlexColumnWidth()},
      children: [
        for (final e in rows.entries)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: text(e.key, bold: true),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: text(e.value.isEmpty ? '-' : e.value),
              ),
            ],
          ),
      ],
    );
  }
}

class _PdfFonts {
  const _PdfFonts({
    required this.base,
    required this.bold,
    required this.bengali,
    required this.bengaliBold,
    required this.arabic,
  });

  final pw.Font base;
  final pw.Font bold;
  final pw.Font bengali;
  final pw.Font bengaliBold;
  final pw.Font arabic;

  static Future<_PdfFonts> load(
    Future<pw.Font> Function(String fileName) font,
  ) async {
    final loaded = await Future.wait([
      font('NotoSans-Regular.ttf'),
      font('NotoSans-Bold.ttf'),
      font('NotoSansBengali-Regular.ttf'),
      font('NotoSansBengali-Bold.ttf'),
      font('NotoSansArabic-Regular.ttf'),
    ]);
    return _PdfFonts(
      base: loaded[0],
      bold: loaded[1],
      bengali: loaded[2],
      bengaliBold: loaded[3],
      arabic: loaded[4],
    );
  }
}
