import 'dart:math' as math;

import 'package:exam_guard/features/radar/model/radar_levels.dart';

/// Smooths raw BLE RSSI and derives a stable hot/cold trend from it.
///
/// Raw RSSI jumps ±5 dB between packets even when nothing moves, so:
/// * the value is smoothed with a time-based EMA (≈ alpha 0.2 at 10 Hz);
/// * the trend compares the smoothed value now with the smoothed value
///   [trendWindow] ago, and needs [enterDb] to switch and falls back only
///   once the change drops under [exitDb] (hysteresis).
class RssiTrendFilter {
  static const Duration timeConstant = Duration(milliseconds: 500);
  static const Duration trendWindow = Duration(milliseconds: 1500);

  /// Packets further apart than this are not comparable; start over.
  static const Duration maxGap = Duration(seconds: 3);
  static const double enterDb = 3.0;
  static const double exitDb = 1.5;

  /// The EMA starts at the first (noisy) packet; samples before it has
  /// settled are not used as a trend reference.
  static const Duration warmUp = Duration(seconds: 1);

  double? _smoothed;
  DateTime? _lastAt;
  DateTime? _startedAt;
  ProximityTrend _trend = ProximityTrend.stationary;
  final List<(DateTime, double)> _samples = [];

  double? get smoothed => _smoothed;
  ProximityTrend get trend => _trend;

  void reset() {
    _smoothed = null;
    _lastAt = null;
    _startedAt = null;
    _trend = ProximityTrend.stationary;
    _samples.clear();
  }

  void add(int rssi, DateTime at) {
    final last = _lastAt;
    final previous = _smoothed;
    if (previous == null || last == null || at.difference(last) > maxGap) {
      reset();
      _smoothed = rssi.toDouble();
      _startedAt = at;
    } else {
      final dtSeconds = math.max(0, at.difference(last).inMicroseconds) / 1e6;
      final tau = timeConstant.inMicroseconds / 1e6;
      final alpha = (1 - math.exp(-dtSeconds / tau)).clamp(0.05, 1.0);
      _smoothed = previous + alpha * (rssi - previous);
    }
    _lastAt = at;

    final current = _smoothed!;
    _samples.add((at, current));
    _samples.removeWhere((s) => at.difference(s.$1) > trendWindow * 2);

    double? reference;
    final settledAt = _startedAt!.add(warmUp);
    for (final (time, value) in _samples) {
      if (at.difference(time) < trendWindow) break;
      if (time.isBefore(settledAt)) continue;
      reference = value;
    }
    _trend = reference == null
        ? ProximityTrend.stationary
        : nextTrend(_trend, current - reference);
  }

  /// [changeDb] > 0 means the signal got stronger (closer).
  static ProximityTrend nextTrend(ProximityTrend current, double changeDb) {
    if (current == ProximityTrend.approaching && changeDb > exitDb) {
      return ProximityTrend.approaching;
    }
    if (current == ProximityTrend.receding && changeDb < -exitDb) {
      return ProximityTrend.receding;
    }
    if (changeDb >= enterDb) return ProximityTrend.approaching;
    if (changeDb <= -enterDb) return ProximityTrend.receding;
    return ProximityTrend.stationary;
  }
}
