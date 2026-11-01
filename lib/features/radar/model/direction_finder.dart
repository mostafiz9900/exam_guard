import 'dart:math' as math;

import 'package:meta/meta.dart';

/// How sure the direction is.
enum DirectionConfidence {
  /// Clear peak, strong body shadow behind.
  good,

  /// A peak, but weak contrast or a second direction nearly as strong.
  fair,

  /// No usable direction (too close, too far, or reflections everywhere).
  unclear,
}

@immutable
class DirectionResult {
  const DirectionResult({
    required this.bearing,
    required this.contrastDb,
    required this.confidence,
  });

  /// Degrees clockwise from magnetic north towards the device.
  final double bearing;

  /// How much stronger the signal is facing the device than facing away.
  final double contrastDb;
  final DirectionConfidence confidence;
}

/// Direction finding with the invigilator's own body as the shield.
///
/// The phone is held in front of the chest while the person turns once all
/// the way round. A 2.4 GHz signal passing through a body loses 10–20 dB,
/// so it is strongest when the person faces the device. Samples are binned
/// by compass heading (10° bins); the strongest smoothed direction wins.
class DirectionFinder {
  static const int bins = 36;
  static const double binDegrees = 360 / bins;

  /// Share of directions that must have samples for a result.
  static const double minCoverage = 0.75;

  /// Facing-vs-away difference for a confident result (dB).
  static const double goodContrast = 8;
  static const double fairContrast = 4;

  final List<List<int>> _samples = List.generate(bins, (_) => <int>[]);

  static int binOf(double heading) => ((heading % 360) / binDegrees).floor();

  void add(double heading, int rssi) {
    if (rssi >= 0 || rssi < -110) return;
    _samples[binOf(heading)].add(rssi);
  }

  void clear() {
    for (final s in _samples) {
      s.clear();
    }
  }

  int get sampleCount => _samples.fold(0, (n, s) => n + s.length);

  /// 0–1: share of directions with at least one sample.
  double get coverage => _samples.where((s) => s.isNotEmpty).length / bins;

  /// Mean RSSI per direction bin, null where nothing was heard yet.
  List<double?> get levels => [
    for (final s in _samples)
      s.isEmpty ? null : s.reduce((a, b) => a + b) / s.length,
  ];

  /// Null until [minCoverage] is reached.
  ///
  /// The bearing comes from the first harmonic (a cosine fitted to all
  /// directions), which averages out fading far better than picking the
  /// single strongest bin: the top of the body-shadow curve is flat.
  DirectionResult? result() {
    if (coverage < minCoverage) return null;
    final raw = _filled(levels);
    final mean = raw.reduce((a, b) => a + b) / bins;
    var c = 0.0, s = 0.0;
    for (var i = 0; i < bins; i++) {
      final a = (i + 0.5) * binDegrees * math.pi / 180;
      c += (raw[i] - mean) * math.cos(a);
      s += (raw[i] - mean) * math.sin(a);
    }
    final bearing = (math.atan2(s, c) * 180 / math.pi + 360) % 360;
    // Peak-to-trough of the fitted cosine: facing vs facing away.
    final contrast = 4 * math.sqrt(c * c + s * s) / bins;

    // Reflections: a second strong direction ≥ 90° from the bearing.
    final smooth = [
      for (var i = 0; i < bins; i++)
        (raw[(i - 1 + bins) % bins] + 2 * raw[i] + raw[(i + 1) % bins]) / 4,
    ];
    final peakBin = binOf(bearing);
    var near = double.negativeInfinity;
    var rival = double.negativeInfinity;
    for (var i = 0; i < bins; i++) {
      final sep = (i - peakBin).abs() % bins;
      if (math.min(sep, bins - sep) <= 2) {
        near = math.max(near, smooth[i]);
      } else if (math.min(sep, bins - sep) >= 9) {
        rival = math.max(rival, smooth[i]);
      }
    }
    final margin = near - rival;

    final confidence = contrast < fairContrast || margin < 0
        ? DirectionConfidence.unclear
        : contrast >= goodContrast && margin >= 2
        ? DirectionConfidence.good
        : DirectionConfidence.fair;
    return DirectionResult(
      bearing: bearing,
      contrastDb: contrast,
      confidence: confidence,
    );
  }

  /// Gaps filled by linear interpolation around the circle.
  static List<double> _filled(List<double?> v) {
    final known = [
      for (var i = 0; i < v.length; i++)
        if (v[i] != null) i,
    ];
    return [
      for (var i = 0; i < v.length; i++)
        v[i] ??
            () {
              final next = known.firstWhere(
                (k) => k > i,
                orElse: () => known.first + v.length,
              );
              final prev = known.lastWhere(
                (k) => k < i,
                orElse: () => known.last - v.length,
              );
              final a = v[(prev + v.length) % v.length]!;
              final b = v[next % v.length]!;
              return a + (b - a) * (i - prev) / (next - prev);
            }(),
    ];
  }
}

/// Eight compass points for [bearing] (0 = north): index 0–7 → N, NE, E, …
int compassPoint(double bearing) => (((bearing % 360) + 22.5) ~/ 45) % 8;

/// Eight hall directions relative to the front of the hall
/// ([frontHeading]): 0 front, 1 front-right, 2 right, 3 back-right, 4 back,
/// 5 back-left, 6 left, 7 front-left.
int hallPoint(double bearing, double frontHeading) =>
    compassPoint((bearing - frontHeading + 360) % 360);

/// Smallest signed angle from [from] to [to], −180..180 (clockwise > 0).
double turnTo(double from, double to) => ((to - from + 540) % 360) - 180;
