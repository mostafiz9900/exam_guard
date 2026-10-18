import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:flutter_test/flutter_test.dart';

ActionLogModel _log(String? seat, LogSeverity severity) => ActionLogModel(
  deviceName: 'Phone',
  deviceId: 'N/A',
  category: 'Bluetooth Device',
  severity: severity,
  location: '',
  notes: '',
  createdAt: DateTime(2026, 10, 13, 9),
  seat: seat,
);

void main() {
  group('SeatId', () {
    test('row letter + 1-based column', () {
      expect(SeatId.format(0, 0), 'A1');
      expect(SeatId.format(2, 3), 'C4');
      expect(SeatId.format(25, 11), 'Z12');
    });

    test('rows past Z continue AA, AB, …', () {
      expect(SeatId.rowLabel(26), 'AA');
      expect(SeatId.rowLabel(27), 'AB');
      expect(SeatId.rowLabel(51), 'AZ');
      expect(SeatId.rowLabel(52), 'BA');
    });

    test('parse is the inverse of format', () {
      for (final (r, c) in [(0, 0), (2, 3), (25, 9), (26, 0), (60, 14)]) {
        expect(SeatId.parse(SeatId.format(r, c)), (r, c));
      }
      expect(SeatId.parse('c4'), (2, 3));
      expect(SeatId.parse('Desk 4'), isNull);
      expect(SeatId.parse('A0'), isNull);
      expect(SeatId.parse(null), isNull);
    });
  });

  test('summarizeSeats counts per seat and keeps the highest severity', () {
    final summary = summarizeSeats([
      _log('C4', LogSeverity.low),
      _log('C4', LogSeverity.critical),
      _log('C4', LogSeverity.medium),
      _log('A1', LogSeverity.high),
      _log(null, LogSeverity.critical),
      _log(' ', LogSeverity.critical),
    ]);
    expect(summary.keys, unorderedEquals(['C4', 'A1']));
    expect(summary['C4']!.count, 3);
    expect(summary['C4']!.highestSeverity, LogSeverity.critical);
    expect(summary['A1']!.highestSeverity, LogSeverity.high);
  });
}
