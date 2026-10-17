import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';
import 'package:exam_guard/core/services/pdf/pdf_service_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a PDF with Bangla, Arabic and typographic characters', () async {
    var loads = 0;
    final service = PdfServiceImpl(
      loadAsset: (key) {
        loads++;
        return rootBundle.load(key);
      },
    );
    const document = PdfTableDocument(
      title: 'ExamGuard — Exam Security Session Report',
      infoRows: {
        'Institute': 'ঢাকা কলেজ',
        'Room': '12/B',
        'Inspector': 'محمد أحمد',
      },
      summary: 'Incidents: 2  ·  Critical: 1',
      tableHeaders: ['Time', 'Device', 'Notes'],
      tableRows: [
        ['10:00', 'Rahim’s AirPods', 'পরীক্ষার্থীর পকেটে পাওয়া গেছে'],
        ['10:05', 'هاتف', 'تحت الطاولة (Desk 4)'],
      ],
      closingText: 'Inspector signature: ______',
    );

    final bytes = await service.buildTableDocument(document);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // Fonts are loaded once and reused.
    await service.buildTableDocument(document);
    expect(loads, 5);
  });

  test('font loading failure surfaces as PdfGenerationException', () async {
    final service = PdfServiceImpl(
      loadAsset: (key) async => throw StateError('missing $key'),
    );
    await expectLater(
      service.buildTableDocument(const PdfTableDocument(title: 'x')),
      throwsA(isA<PdfGenerationException>()),
    );
  });
}
