import 'package:meta/meta.dart';

/// Average signal of the target measured while standing at one seat.
@immutable
class SeatReading {
  const SeatReading({required this.averageRssi, required this.packets});

  /// Null when fewer than [SeatSampler.minPackets] packets arrived.
  final double? averageRssi;
  final int packets;

  bool get hasSignal => averageRssi != null;

  @override
  bool operator ==(Object other) =>
      other is SeatReading &&
      other.averageRssi == averageRssi &&
      other.packets == packets;

  @override
  int get hashCode => Object.hash(averageRssi, packets);
}

/// Collects the smoothed RSSI of the target during one seat sample.
class SeatSampler {
  static const int minPackets = 3;

  final List<double> _values = [];

  int get packets => _values.length;

  void start() => _values.clear();

  /// [smoothedRssi] is the smoothed value after this packet.
  void add(double smoothedRssi) => _values.add(smoothedRssi);

  SeatReading finish() {
    if (_values.length < minPackets) {
      return SeatReading(averageRssi: null, packets: _values.length);
    }
    final sum = _values.fold<double>(0, (a, b) => a + b);
    return SeatReading(
      averageRssi: sum / _values.length,
      packets: _values.length,
    );
  }
}

/// How clearly the strongest seat stands out from the runner-up.
enum SweepConfidence {
  high,
  medium,
  low;

  static const double highMarginDb = 6;
  static const double mediumMarginDb = 3;

  /// [marginDb] is best minus second best; null when only one seat has a
  /// signal (nothing to compare with).
  static SweepConfidence fromMargin(double? marginDb) {
    if (marginDb == null) return SweepConfidence.low;
    if (marginDb >= highMarginDb) return SweepConfidence.high;
    if (marginDb >= mediumMarginDb) return SweepConfidence.medium;
    return SweepConfidence.low;
  }

  String get labelKey => 'sweep_confidence_$name';
}

/// Strongest seat of a sweep and how sure that is.
@immutable
class SeatSweepResult {
  const SeatSweepResult({
    required this.bestSeat,
    required this.bestRssi,
    required this.secondSeat,
    required this.secondRssi,
    required this.seatsWithSignal,
  });

  final String bestSeat;
  final double bestRssi;
  final String? secondSeat;
  final double? secondRssi;
  final int seatsWithSignal;

  double? get marginDb {
    final second = secondRssi;
    return second == null ? null : bestRssi - second;
  }

  SweepConfidence get confidence => SweepConfidence.fromMargin(marginDb);

  /// Best seat among [readings] with a signal; null when none has one.
  static SeatSweepResult? analyze(Map<String, SeatReading> readings) {
    final ranked = [
      for (final e in readings.entries)
        if (e.value.averageRssi != null) (e.key, e.value.averageRssi!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (ranked.isEmpty) return null;
    final second = ranked.length > 1 ? ranked[1] : null;
    return SeatSweepResult(
      bestSeat: ranked.first.$1,
      bestRssi: ranked.first.$2,
      secondSeat: second?.$1,
      secondRssi: second?.$2,
      seatsWithSignal: ranked.length,
    );
  }
}
