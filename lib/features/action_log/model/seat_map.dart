import 'package:meta/meta.dart';

import 'package:exam_guard/features/session/model/action_log_model.dart';

/// Seat ids on a room's seat map: rows are lettered from the front
/// (A, B, … Z, AA, AB, …), columns numbered from 1, e.g. "C4".
abstract final class SeatId {
  /// Letter of the zero-based [row]: 0 → A, 25 → Z, 26 → AA.
  static String rowLabel(int row) {
    assert(row >= 0);
    var n = row + 1;
    final buffer = StringBuffer();
    while (n > 0) {
      final rem = (n - 1) % 26;
      buffer.write(String.fromCharCode(65 + rem));
      n = (n - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Number of the zero-based [col]: 0 → "1".
  static String colLabel(int col) => '${col + 1}';

  /// Seat id of zero-based [row] and [col], e.g. (2, 3) → "C4".
  static String format(int row, int col) => '${rowLabel(row)}${colLabel(col)}';

  static final _pattern = RegExp(r'^([A-Za-z]{1,3})\s*(\d{1,4})$');

  /// Zero-based (row, col) of a seat id, or null when it is not one.
  static (int, int)? parse(String? seat) {
    final match = _pattern.firstMatch(seat?.trim() ?? '');
    if (match == null) return null;
    var row = 0;
    for (final unit in match.group(1)!.toUpperCase().codeUnits) {
      row = row * 26 + (unit - 64);
    }
    final col = int.parse(match.group(2)!);
    if (col < 1) return null;
    return (row - 1, col - 1);
  }
}

/// Incidents recorded at one seat.
@immutable
class SeatSummary {
  const SeatSummary({required this.count, required this.highestSeverity});

  final int count;
  final LogSeverity highestSeverity;
}

/// Incident count and highest severity per seat id (logs without a seat are
/// ignored). [LogSeverity.values] is ordered most severe first.
Map<String, SeatSummary> summarizeSeats(Iterable<ActionLogModel> logs) {
  final result = <String, SeatSummary>{};
  for (final log in logs) {
    final seat = log.seat?.trim() ?? '';
    if (seat.isEmpty) continue;
    final previous = result[seat];
    result[seat] = SeatSummary(
      count: (previous?.count ?? 0) + 1,
      highestSeverity:
          previous == null ||
              log.severity.index < previous.highestSeverity.index
          ? log.severity
          : previous.highestSeverity,
    );
  }
  return result;
}
