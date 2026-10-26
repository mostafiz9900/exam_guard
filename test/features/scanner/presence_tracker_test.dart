// Device timeline: presence intervals, samples, rotation merge, toggling.

import 'package:exam_guard/features/scanner/model/presence_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 26, 9);
DateTime _at(int s) => _t0.add(Duration(seconds: s));

void main() {
  late PresenceTracker p;
  setUp(() => p = PresenceTracker());

  test('continuous sightings make one interval with sampled signal', () {
    for (var s = 0; s <= 60; s++) {
      p.record('A', -60 - (s % 3), _at(s));
    }
    final h = p.historyOf('A')!;
    expect(h.intervals, hasLength(1));
    expect(h.firstSeen, _at(0));
    expect(h.lastSeen, _at(60));
    expect(h.timePresent, const Duration(seconds: 60));
    // One sample per 5 s: 0, 5, …, 60.
    expect(h.samples, hasLength(13));
    expect(h.peakRssi, -60);
    expect(h.reappearances, isEmpty);
  });

  test('a silence of 30 s or more is an absence; shorter gaps are not', () {
    p.record('A', -60, _at(0));
    p.record('A', -60, _at(20)); // 20 s gap: same presence
    p.record('A', -60, _at(60)); // 40 s gap: came back
    final h = p.historyOf('A')!;
    expect(h.intervals, hasLength(2));
    expect(h.reappearances, [_at(60)]);
    expect(h.timePresent, const Duration(seconds: 20));
  });

  test('3 reappearances within 15 min = toggling (BLE only)', () {
    for (final id in ['BLE', 'WIFI']) {
      for (var i = 0; i < 4; i++) {
        p.record(id, -60, _at(i * 120), canToggle: id == 'BLE');
        p.record(id, -60, _at(i * 120 + 10), canToggle: id == 'BLE');
      }
    }
    expect(p.togglingIds(_at(500)), {'BLE'});
  });

  test('old reappearances stop counting', () {
    for (var i = 0; i < 4; i++) {
      p.record('A', -60, _at(i * 60));
    }
    expect(p.togglingIds(_at(200)), {'A'});
    expect(p.togglingIds(_at(200 + 20 * 60)), isEmpty);
  });

  test('a rotated address continues the same history', () {
    p.record('OLD', -55, _at(0));
    p.record('OLD', -50, _at(10));
    p.alias('OLD', 'NEW');
    p.record('NEW', -52, _at(15));
    expect(p.historyOf('OLD'), isNull);
    final h = p.historyOf('NEW')!;
    expect(h.firstSeen, _at(0));
    expect(h.peakRssi, -50);
    expect(h.intervals, hasLength(1));
  });

  test('history older than 30 min is pruned', () {
    p.record('A', -60, _at(0));
    p.prune(_at(29 * 60));
    expect(p.historyOf('A'), isNotNull);
    p.prune(_at(31 * 60));
    expect(p.historyOf('A'), isNull);
  });
}
