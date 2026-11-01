// Body-shadow direction finding: turn once, the strongest heading points
// at the device.

import 'dart:math' as math;

import 'package:exam_guard/features/radar/model/direction_finder.dart';
import 'package:flutter_test/flutter_test.dart';

/// One slow turn: RSSI per degree with the body shadowing the far side.
DirectionFinder turn({
  required double target,
  double shadowDb = 15,
  double noiseDb = 3,
  double from = 0,
  double to = 360,
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  final f = DirectionFinder();
  for (var h = from; h < to; h += 2) {
    final off = (h - target) * math.pi / 180;
    final level = -60 - shadowDb * (1 - math.cos(off)) / 2;
    f.add(h % 360, (level + (rnd.nextDouble() * 2 - 1) * noiseDb).round());
  }
  return f;
}

double angleBetween(double a, double b) => turnTo(a, b).abs();

void main() {
  test('finds the device direction within 10° despite ±3 dB fading', () {
    for (final target in [0.0, 45, 135, 220, 310]) {
      for (var seed = 1; seed <= 6; seed++) {
        final r = turn(target: target.toDouble(), seed: seed).result()!;
        expect(
          angleBetween(r.bearing, target.toDouble()),
          lessThan(10),
          reason: 'target $target seed $seed',
        );
        expect(r.confidence, DirectionConfidence.good);
        expect(r.contrastDb, greaterThan(8));
      }
    }
  });

  test('no result until most of the circle is covered', () {
    final f = turn(target: 90, to: 200);
    expect(f.coverage, lessThan(DirectionFinder.minCoverage));
    expect(f.result(), isNull);
  });

  test('no body shadow (device right next to you, or far) is unclear', () {
    final r = turn(target: 90, shadowDb: 1, noiseDb: 1).result()!;
    expect(r.confidence, DirectionConfidence.unclear);
  });

  test('two equal directions (reflections) are never "good"', () {
    final f = DirectionFinder();
    for (var h = 0.0; h < 360; h += 2) {
      final a = math.cos((h - 60) * math.pi / 180);
      final b = math.cos((h - 240) * math.pi / 180);
      f.add(h, (-75 + 8 * math.max(a, b)).round());
    }
    expect(f.result()!.confidence, isNot(DirectionConfidence.good));
  });

  test('gaps in the turn are interpolated, not treated as silence', () {
    final f = turn(target: 180, from: 0, to: 300);
    expect(f.coverage, greaterThanOrEqualTo(DirectionFinder.minCoverage));
    expect(angleBetween(f.result()!.bearing, 180), lessThan(20));
  });

  test('impossible readings are ignored', () {
    final f = DirectionFinder()
      ..add(10, 0)
      ..add(10, 127)
      ..add(10, -200);
    expect(f.sampleCount, 0);
  });

  group('words', () {
    test('compass points', () {
      expect(<double>[0, 44, 46, 90, 180, 270, 337, 359].map(compassPoint), [
        0,
        1,
        1,
        2,
        4,
        6,
        7,
        0,
      ]);
    });

    test('hall points are relative to the front of the hall', () {
      // Front of the hall is due east (90°).
      expect(hallPoint(90, 90), 0); // front
      expect(hallPoint(180, 90), 2); // right
      expect(hallPoint(270, 90), 4); // back
      expect(hallPoint(45, 90), 7); // front-left
      expect(hallPoint(225, 90), 3); // back-right
    });

    test('turn direction is the short way round', () {
      expect(turnTo(350, 10), 20);
      expect(turnTo(10, 350), -20);
      expect(turnTo(0, 180).abs(), 180);
    });
  });
}
