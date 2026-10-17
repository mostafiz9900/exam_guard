import 'dart:typed_data';
import 'dart:ui' show Color;

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
    final ui = _Ui(fonts, _text);

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.bold,
          fontFallback: [fonts.bengali, fonts.arabic],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        maxPages: 500,
        header: (context) => context.pageNumber == 1
            ? _header(document, ui)
            : _compactHeader(document, ui),
        footer: (context) => _footer(document, context, ui),
        build: (context) => [
          if (document.metaRows.isNotEmpty) ...[
            if (document.metaTitle != null)
              _sectionTitle(document.metaTitle!, ui),
            _metaGrid(document.metaRows, ui),
          ],
          if (document.summaryItems.isNotEmpty ||
              document.summaryText != null) ...[
            if (document.summaryTitle != null)
              _sectionTitle(document.summaryTitle!, ui),
            if (document.summaryItems.isNotEmpty)
              _summaryBoxes(document.summaryItems, ui),
            if (document.summaryText != null)
              _verdict(document.summaryText!, document.summaryColor, ui),
          ],
          if (document.tableTitle != null)
            _sectionTitle(document.tableTitle!, ui),
          if (document.tableRows.isNotEmpty)
            _table(document.tableColumns, document.tableRows, ui)
          else if (document.emptyTableText != null ||
              document.emptyTableTitle != null)
            _emptyState(document, ui),
          if (document.signatures.isNotEmpty)
            _signatures(document.signatures, ui),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------- layout --

  static const _brand = PdfColor.fromInt(0xFF1E3A5F);
  static const _ink = PdfColor.fromInt(0xFF1F2937);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFC4C9D1);
  static const _shade = PdfColor.fromInt(0xFFEEF0F3);
  static const _zebra = PdfColor.fromInt(0xFFF8F9FA);

  static PdfColor _pdfColor(Color c) => PdfColor(c.r, c.g, c.b);

  /// [c] mixed with white; [amount] 0 = white, 1 = [c].
  static PdfColor _tint(PdfColor c, double amount) => PdfColor(
    1 - (1 - c.red) * amount,
    1 - (1 - c.green) * amount,
    1 - (1 - c.blue) * amount,
  );

  pw.Widget _header(PdfTableDocument document, _Ui ui) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (document.brand != null)
                  ui.text(
                    document.brand!,
                    bold: true,
                    fontSize: 20,
                    color: _brand,
                  ),
                pw.SizedBox(height: 2),
                ui.text(document.title, bold: true, fontSize: 12, color: _ink),
              ],
            ),
          ),
          if (document.headerMeta.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final m in document.headerMeta)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        ui.text('${m.label}  ', fontSize: 8, color: _muted),
                        ui.text(m.value, bold: true, fontSize: 8, color: _ink),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _compactHeader(PdfTableDocument document, _Ui ui) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          if (document.brand != null) ...[
            ui.text(document.brand!, bold: true, fontSize: 9, color: _brand),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: ui.text(document.title, fontSize: 8.5, color: _muted),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(PdfTableDocument document, pw.Context context, _Ui ui) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: ui.text(
              document.footerText ?? '',
              fontSize: 7.5,
              color: _muted,
            ),
          ),
          ui.text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            fontSize: 7.5,
            color: _muted,
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title, _Ui ui) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: ui.text(
        title.toUpperCase(),
        bold: true,
        fontSize: 9,
        color: _brand,
      ),
    );
  }

  pw.Widget _metaGrid(List<PdfMetaItem> items, _Ui ui) {
    pw.Widget label(String v) => pw.Container(
      color: _shade,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: ui.text(v, bold: true, fontSize: 8.5, color: _muted),
    );
    pw.Widget value(String v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: ui.text(v.trim().isEmpty ? '-' : v, fontSize: 9, color: _ink),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(70),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(70),
        3: pw.FlexColumnWidth(),
      },
      children: [
        for (var i = 0; i < items.length; i += 2)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.full,
            children: [
              label(items[i].label),
              value(items[i].value),
              if (i + 1 < items.length) ...[
                label(items[i + 1].label),
                value(items[i + 1].value),
              ] else ...[
                pw.Container(color: _shade),
                pw.SizedBox(),
              ],
            ],
          ),
      ],
    );
  }

  pw.Widget _summaryBoxes(List<PdfSummaryItem> items, _Ui ui) {
    final boxes = <pw.Widget>[];
    for (final item in items) {
      final accent = item.color == null ? null : _pdfColor(item.color!);
      if (boxes.isNotEmpty) boxes.add(pw.SizedBox(width: 6));
      boxes.add(
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            decoration: pw.BoxDecoration(
              color: accent == null ? null : _tint(accent, 0.07),
              border: pw.Border(
                top: pw.BorderSide(color: accent ?? _ink, width: 2.5),
                left: const pw.BorderSide(color: _line, width: 0.5),
                right: const pw.BorderSide(color: _line, width: 0.5),
                bottom: const pw.BorderSide(color: _line, width: 0.5),
              ),
            ),
            child: pw.Column(
              children: [
                ui.text(
                  item.value,
                  bold: true,
                  fontSize: 16,
                  color: accent ?? _ink,
                ),
                pw.SizedBox(height: 1),
                ui.text(item.label.toUpperCase(), fontSize: 7, color: _muted),
              ],
            ),
          ),
        ),
      );
    }
    return pw.Row(children: boxes);
  }

  pw.Widget _verdict(String text, Color? color, _Ui ui) {
    final accent = color == null ? _ink : _pdfColor(color);
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _tint(accent, 0.06),
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: ui.text(text, bold: true, fontSize: 10, color: accent),
    );
  }

  pw.Widget _table(
    List<PdfTableColumn> columns,
    List<List<PdfTableCell>> rows,
    _Ui ui,
  ) {
    const cellPadding = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4);

    pw.Widget cell(PdfTableCell c) {
      if (c.color == null) {
        return pw.Padding(
          padding: cellPadding,
          child: ui.text(c.text, bold: c.bold, fontSize: 7.5, color: _ink),
        );
      }
      final color = _pdfColor(c.color!);
      return pw.Padding(
        padding: cellPadding,
        child: pw.Align(
          alignment: pw.Alignment.topLeft,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: pw.BoxDecoration(
              color: _tint(color, 0.1),
              border: pw.Border.all(color: color, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: ui.text(c.text, bold: true, fontSize: 6.5, color: color),
          ),
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(columns[i].flex),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _shade),
          children: [
            for (final c in columns)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                child: ui.text(c.label, bold: true, fontSize: 7.5, color: _ink),
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: r.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
            children: [
              for (var i = 0; i < columns.length; i++)
                cell(i < rows[r].length ? rows[r][i] : const PdfTableCell('')),
            ],
          ),
      ],
    );
  }

  pw.Widget _emptyState(PdfTableDocument document, _Ui ui) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: pw.BoxDecoration(
        color: _zebra,
        border: pw.Border.all(color: _line, width: 0.5),
      ),
      child: pw.Column(
        children: [
          if (document.emptyTableTitle != null)
            ui.text(
              document.emptyTableTitle!,
              bold: true,
              fontSize: 10,
              color: _ink,
              align: pw.TextAlign.center,
            ),
          if (document.emptyTableTitle != null &&
              document.emptyTableText != null)
            pw.SizedBox(height: 3),
          if (document.emptyTableText != null)
            ui.text(
              document.emptyTableText!,
              fontSize: 8.5,
              color: _muted,
              align: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  pw.Widget _signatures(List<PdfSignatureBlock> blocks, _Ui ui) {
    pw.Widget line({double height = 0.6}) =>
        pw.Container(height: height, color: _ink);

    pw.Widget field(String label, String? value) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 34,
            child: ui.text(label, fontSize: 8, color: _muted),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 2, left: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _line, width: 0.6),
                ),
              ),
              child: ui.text(
                (value ?? '').trim().isEmpty ? ' ' : value!,
                fontSize: 9,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );

    final children = <pw.Widget>[];
    for (final b in blocks) {
      if (children.isNotEmpty) children.add(pw.SizedBox(width: 36));
      children.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ui.text(b.role, bold: true, fontSize: 9.5, color: _ink),
              pw.SizedBox(height: 34),
              line(),
              pw.SizedBox(height: 2),
              ui.text('Signature', fontSize: 7, color: _muted),
              field('Name', b.name),
              field('Date', null),
            ],
          ),
        ),
      );
    }

    return pw.Inseparable(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 28),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  /// A text widget whose font and direction follow its script: Arabic text is
  /// shaped right-to-left, Bengali text uses the Bengali font as primary so
  /// its characters stay in one run instead of glyph-by-glyph fallback.
  pw.Widget _text(
    String value,
    _PdfFonts fonts, {
    bool bold = false,
    double? fontSize,
    PdfColor? color,
    pw.TextAlign? align,
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
      textAlign: align,
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : null,
        font: primary,
        fontNormal: primary,
        fontBold: primary,
        fontFallback: fallback,
      ),
    );
  }
}

typedef _TextBuilder = pw.Widget Function(
  String value,
  _PdfFonts fonts, {
  bool bold,
  double? fontSize,
  PdfColor? color,
  pw.TextAlign? align,
});

/// Binds the loaded fonts to the script-aware text builder.
class _Ui {
  const _Ui(this._fonts, this._builder);

  final _PdfFonts _fonts;
  final _TextBuilder _builder;

  pw.Widget text(
    String value, {
    bool bold = false,
    double? fontSize,
    PdfColor? color,
    pw.TextAlign? align,
  }) => _builder(
    value,
    _fonts,
    bold: bold,
    fontSize: fontSize,
    color: color,
    align: align,
  );
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
