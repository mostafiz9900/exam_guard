// Placing a device on the seat map from what fixed nodes hear.

import 'dart:math' as math;

import 'package:exam_guard/features/hall_map/model/hall_locator.dart';
import 'package:exam_guard/features/scanner/model/distance_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

/// RSSI a node would hear from [seats] away under the default model.
int rssiAt(double seats, {double n = DistanceEstimate.defaultPathLoss}) =>
    (DistanceEstimate.defaultRssiAt1m -
            10 * n * math.log(seats * HallLocator.seatMeters) / math.ln10)
        .round();

LocatorReading reading(
  String id,
  MapPoint node,
  MapPoint device, {
  double n = DistanceEstimate.defaultPathLoss,
}) => LocatorReading(
  nodeId: id,
  at: node,
  rssi: rssiAt(node.distanceTo(device), n: n),
);

void main() {
  // 6 rows × 8 columns; nodes in three corners.
  const rows = 6, cols = 8;
  final front = const MapPoint.seat(0, 0);
  final backLeft = const MapPoint.seat(5, 0);
  final backRight = const MapPoint.seat(5, 7);

  test('three nodes that agree find the seat', () {
    final device = const MapPoint.seat(3, 4); // D5
    final r = HallLocator.locate(
      [
        reading('a', front, device),
        reading('b', backLeft, device),
        reading('c', backRight, device),
      ],
      rows: rows,
      cols: cols,
    )!;
    expect(r.at.distanceTo(device), lessThan(0.6));
    expect(r.seat, 'D5');
    expect(r.confidence, LocatorConfidence.good);
  });

  test('one node only says "within this distance"', () {
    final r = HallLocator.locate(
      [LocatorReading(nodeId: 'a', at: backLeft, rssi: rssiAt(3))],
      rows: rows,
      cols: cols,
    )!;
    expect(r.at, backLeft);
    expect(r.radius, closeTo(3, 0.3));
    expect(r.confidence, LocatorConfidence.low);
  });

  test('two nodes land between them, nearer the stronger', () {
    final r = HallLocator.locate(
      [
        LocatorReading(nodeId: 'a', at: backLeft, rssi: rssiAt(2)),
        LocatorReading(nodeId: 'b', at: backRight, rssi: rssiAt(6)),
      ],
      rows: rows,
      cols: cols,
    )!;
    expect(r.at.x, lessThan(4));
    expect(r.confidence, LocatorConfidence.medium);
  });

  test('noisy, contradicting readings widen the area and stay on the map', () {
    final r = HallLocator.locate(
      [
        LocatorReading(nodeId: 'a', at: front, rssi: -40),
        LocatorReading(nodeId: 'b', at: backLeft, rssi: -45),
        LocatorReading(nodeId: 'c', at: backRight, rssi: -42),
      ],
      rows: rows,
      cols: cols,
    )!;
    expect(r.radius, greaterThan(1.8));
    expect(r.confidence, LocatorConfidence.medium);
    expect(r.at.x, inInclusiveRange(0, cols));
    expect(r.at.y, inInclusiveRange(0, rows));
  });

  test('nothing heard → no estimate', () {
    expect(HallLocator.locate([], rows: rows, cols: cols), isNull);
  });

  group('calibration from nodes hearing each other', () {
    test('learns a lossy room', () {
      final n = HallLocator.calibrate([
        for (final m in [3.0, 6.0, 8.4])
          (meters: m, rssi: (-59 - 30 * math.log(m) / math.ln10).round()),
      ]);
      expect(n, closeTo(3.0, 0.1));
    });

    test('too close or absurd pairs are ignored or clamped', () {
      expect(HallLocator.calibrate([(meters: 1.0, rssi: -80)]), isNull);
      expect(
        HallLocator.calibrate([(meters: 5, rssi: -30)]),
        HallLocator.minPathLoss,
      );
    });

    test('calibrated loss improves the estimate in a lossy room', () {
      final device = const MapPoint.seat(2, 5);
      final readings = [
        reading('a', front, device, n: 3.2),
        reading('b', backLeft, device, n: 3.2),
        reading('c', backRight, device, n: 3.2),
      ];
      final plain = HallLocator.locate(readings, rows: rows, cols: cols)!;
      final tuned = HallLocator.locate(
        readings,
        rows: rows,
        cols: cols,
        pathLoss: 3.2,
      )!;
      expect(
        tuned.at.distanceTo(device),
        lessThan(plain.at.distanceTo(device)),
      );
      expect(tuned.at.distanceTo(device), lessThan(0.6));
    });
  });
}
