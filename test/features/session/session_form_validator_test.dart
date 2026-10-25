// Setup form rules: Bangla/Arabic letters are letters; junk is rejected.

import 'package:exam_guard/features/session/model/session_form_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('room', () {
    test('required', () {
      expect(SessionFormValidator.room(''), 'room_required');
      expect(SessionFormValidator.room('   '), 'room_required');
    });

    test('real room numbers pass', () {
      for (final r in [
        '204',
        '302-B',
        'Hall 2/A',
        'Lab #3',
        'Room (A)',
        '১২-খ',
        'A.12',
      ]) {
        expect(SessionFormValidator.room(r), isNull, reason: r);
      }
    });

    test('symbols, emoji and punctuation-only are rejected', () {
      for (final r in ['12@B', 'Room 😀', '---', '<b>1</b>', "12'B"]) {
        expect(SessionFormValidator.room(r), 'room_invalid_chars', reason: r);
      }
    });

    test('length limit', () {
      expect(SessionFormValidator.room('A' * 20), isNull);
      expect(SessionFormValidator.room('A' * 21), 'room_too_long');
    });
  });

  group('institute', () {
    test('optional', () => expect(SessionFormValidator.institute(''), isNull));

    test('real names pass, incl. Bangla and digits inside', () {
      for (final n in [
        'Central College',
        'ঢাকা রেসিডেনসিয়াল মডেল কলেজ',
        'Govt. High School No. 2',
        "St. Joseph's (Boys)",
      ]) {
        expect(SessionFormValidator.institute(n), isNull, reason: n);
      }
    });

    test('numbers-only, markup and too long are rejected', () {
      expect(
        SessionFormValidator.institute('12345'),
        'institute_needs_letters',
      );
      expect(
        SessionFormValidator.institute('<script>'),
        'institute_invalid_chars',
      );
      expect(SessionFormValidator.institute('A' * 81), 'institute_too_long');
    });
  });

  group('supervisor', () {
    test('optional', () => expect(SessionFormValidator.supervisor(''), isNull));

    test('real names pass', () {
      for (final n in [
        'Dr. Rahman',
        "O'Neil",
        'Md. Abdur-Rahim',
        'মোঃ করিম',
        'محمد علي',
      ]) {
        expect(SessionFormValidator.supervisor(n), isNull, reason: n);
      }
    });

    test('digits, symbols, too short, too long', () {
      expect(
        SessionFormValidator.supervisor('Rahman 2'),
        'supervisor_no_digits',
      );
      expect(SessionFormValidator.supervisor('রহিম ১'), 'supervisor_no_digits');
      expect(
        SessionFormValidator.supervisor('Rahman!'),
        'supervisor_invalid_chars',
      );
      expect(SessionFormValidator.supervisor('..'), 'supervisor_invalid_chars');
      expect(SessionFormValidator.supervisor('A'), 'supervisor_too_short');
      expect(SessionFormValidator.supervisor('A' * 51), 'supervisor_too_long');
    });
  });

  test('clean collapses whitespace', () {
    expect(SessionFormValidator.clean('  302   -B \n'), '302 -B');
  });
}
