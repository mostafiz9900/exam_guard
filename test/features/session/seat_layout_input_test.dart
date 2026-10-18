import 'package:exam_guard/features/session/view/widgets/seat_layout_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both empty means no seat layout', () {
    final input = SeatLayoutInput.parse('', '  ');
    expect(input.isValid, isTrue);
    expect(input.hasLayout, isFalse);
    expect(input.rows, isNull);
  });

  test('valid rows × columns are parsed', () {
    final input = SeatLayoutInput.parse('6', ' 5 ');
    expect(input.isValid, isTrue);
    expect((input.rows, input.cols), (6, 5));
  });

  test('limits are inclusive (1 and 30)', () {
    expect(SeatLayoutInput.parse('1', '30').isValid, isTrue);
    expect(SeatLayoutInput.parse('30', '1').isValid, isTrue);
  });

  test('out of range or non-numeric values are rejected', () {
    for (final (r, c) in [
      ('0', '5'),
      ('6', '31'),
      ('-1', '5'),
      ('a', '5'),
      ('6', '5.5'),
    ]) {
      final input = SeatLayoutInput.parse(r, c);
      expect(input.isValid, isFalse, reason: '$r × $c');
      expect(input.errorKey, 'setup_seat_err_range');
      expect(input.hasLayout, isFalse);
    }
  });

  test('only one of the two fields filled is rejected', () {
    expect(SeatLayoutInput.parse('6', '').errorKey, 'setup_seat_err_both');
    expect(SeatLayoutInput.parse('', '5').errorKey, 'setup_seat_err_both');
  });
}
