import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/scanner/model/distance_estimate.dart';

/// A point on the seat map in seat units: x along the columns, y along the
/// rows from the front. Seat (row r, col c) spans x ∈ [c, c+1),
/// y ∈ [r, r+1), so its centre is (c + 0.5, r + 0.5).
@immutable
class MapPoint {
  const MapPoint(this.x, this.y);

  /// Centre of seat ([row], [col]).
  const MapPoint.seat(int row, int col) : x = col + 0.5, y = row + 0.5;

  final double x;
  final double y;

  double distanceTo(MapPoint o) => math.sqrt(_sq(x - o.x) + _sq(y - o.y));

  static double _sq(double v) => v * v;

  @override
  bool operator ==(Object other) =>
      other is MapPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'MapPoint(${x.toStringAsFixed(2)}, '
      '${y.toStringAsFixed(2)})';
}

/// One fixed node hearing the device.
@immutable
class LocatorReading {
  const LocatorReading({
    required this.nodeId,
    required this.at,
    required this.rssi,
  });

  final String nodeId;

  /// Where the node is on the map.
  final MapPoint at;
  final int rssi;
}

/// How much to trust an estimate.
enum LocatorConfidence {
  /// One node: only "within this distance of the node".
  low,

  /// Two nodes, or three that disagree.
  medium,

  /// Three or more nodes that agree.
  good,
}

@immutable
class LocatorResult {
  const LocatorResult({
    required this.at,
    required this.radius,
    required this.confidence,
    required this.seat,
  });

  /// Most likely position.
  final MapPoint at;

  /// Uncertainty, in seats: the device is probably inside this circle.
  final double radius;
  final LocatorConfidence confidence;

  /// Seat id under [at], e.g. "C4".
  final String seat;
}

/// Places a device on the seat map from the signal fixed nodes hear.
///
/// Signal strength gives distance only roughly (bodies and desks change
/// it by 10 dB), so the result is an area, never a precise seat: weighted
/// least squares from the nodes' estimated distances, with a radius that
/// grows with disagreement and distance.
abstract final class HallLocator {
  /// Typical exam seat pitch (desk + aisle share), metres per seat.
  static const double seatMeters = 1.2;

  static const double minRadius = 0.7;
  static const double maxRadius = 5;

  /// Path-loss exponents outside this range are measurement noise.
  static const double minPathLoss = 1.6;
  static const double maxPathLoss = 4.0;

  /// Estimated distance in seats for [rssi].
  static double seatsFor(int rssi, double pathLoss) =>
      (DistanceEstimate.meters(rssi, n: pathLoss) / seatMeters).clamp(
        0.2,
        25.0,
      );

  /// Null when there are no readings. The point is kept inside the
  /// [rows] × [cols] seat map.
  static LocatorResult? locate(
    List<LocatorReading> readings, {
    required int rows,
    required int cols,
    double pathLoss = DistanceEstimate.defaultPathLoss,
  }) {
    if (readings.isEmpty || rows <= 0 || cols <= 0) return null;
    final dist = [for (final r in readings) seatsFor(r.rssi, pathLoss)];
    MapPoint clamp(MapPoint p) => MapPoint(
      p.x.clamp(0.0, cols.toDouble()),
      p.y.clamp(0.0, rows.toDouble()),
    );

    if (readings.length == 1) {
      final at = clamp(readings.first.at);
      return LocatorResult(
        at: at,
        radius: dist.first.clamp(minRadius, maxRadius),
        confidence: LocatorConfidence.low,
        seat: _seatAt(at, rows, cols),
      );
    }

    // Start at the centroid weighted by closeness, then minimise the
    // distance error; near nodes are more reliable (error grows with d).
    final w = [for (final d in dist) 1 / (d * d)];
    final sw = w.reduce((a, b) => a + b);
    var p = MapPoint(
      [for (var i = 0; i < w.length; i++) w[i] * readings[i].at.x]
              .reduce((a, b) => a + b) /
          sw,
      [for (var i = 0; i < w.length; i++) w[i] * readings[i].at.y]
              .reduce((a, b) => a + b) /
          sw,
    );
    for (var step = 0; step < 60; step++) {
      var gx = 0.0;
      var gy = 0.0;
      for (var i = 0; i < readings.length; i++) {
        final r = p.distanceTo(readings[i].at);
        if (r < 1e-6) continue;
        final k = (r - dist[i]) / (dist[i] * r);
        gx += k * (p.x - readings[i].at.x);
        gy += k * (p.y - readings[i].at.y);
      }
      p = clamp(MapPoint(p.x - 0.25 * gx, p.y - 0.25 * gy));
    }

    var err = 0.0;
    for (var i = 0; i < readings.length; i++) {
      final e = p.distanceTo(readings[i].at) - dist[i];
      err += e * e;
    }
    final rms = math.sqrt(err / readings.length);
    final nearest = dist.reduce(math.min);
    final radius = (0.5 + rms + 0.2 * nearest).clamp(minRadius, maxRadius);
    final confidence = readings.length >= 3 && radius <= 1.8
        ? LocatorConfidence.good
        : LocatorConfidence.medium;
    return LocatorResult(
      at: p,
      radius: radius,
      confidence: confidence,
      seat: _seatAt(p, rows, cols),
    );
  }

  static String _seatAt(MapPoint p, int rows, int cols) => SeatId.format(
    p.y.floor().clamp(0, rows - 1),
    p.x.floor().clamp(0, cols - 1),
  );

  /// The room's path-loss exponent, learnt from nodes hearing each other
  /// at known distances. Null when no pair is far enough apart (≥ 1.5 m)
  /// to say anything; otherwise the median, kept in a sane range.
  static double? calibrate(List<({double meters, int rssi})> pairs) {
    final ns = <double>[
      for (final p in pairs)
        if (p.meters >= 1.5)
          (DistanceEstimate.defaultRssiAt1m - p.rssi) /
              (10 * math.log(p.meters) / math.ln10),
    ]..sort();
    if (ns.isEmpty) return null;
    final mid = ns.length ~/ 2;
    final median = ns.length.isOdd ? ns[mid] : (ns[mid - 1] + ns[mid]) / 2;
    return median.clamp(minPathLoss, maxPathLoss);
  }
}
