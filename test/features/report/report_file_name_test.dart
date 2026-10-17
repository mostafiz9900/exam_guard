import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeFileName', () {
    test('replaces path separators and other unsafe characters', () {
      expect(safeFileName('room_12/B_2026.pdf'), 'room_12_B_2026.pdf');
      expect(safeFileName(r'a\b:c*?"<>| ক.pdf'), 'a_b_c________.pdf');
    });

    test('falls back when nothing usable is left', () {
      expect(safeFileName('///.pdf'), 'file.pdf');
      expect(safeFileName(''), 'file');
    });

    test('keeps only alphanumeric extensions', () {
      expect(safeFileName('report.p/df'), 'report_p_df');
      expect(safeFileName('.pdf'), '_pdf');
    });
  });

  test('report file name is safe for a room like "12/B"', () {
    final session = SessionModel(
      id: '1',
      instituteName: 'School',
      teacherName: 'T',
      roomNumber: '12/B',
      startTime: DateTime(2026, 10, 13, 9),
    );
    expect(
      ReportRepository.reportFileName(session),
      'examguard_room_12_B_2026-10-13.pdf',
    );
  });
}
