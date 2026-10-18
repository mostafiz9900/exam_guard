import 'package:exam_guard/core/services/audio/haptic_service.dart';

/// "Closeness" of a BLE target: 0–100 % from smoothed RSSI.
///
/// RSSI carries no direction and only a rough distance (body, walls and
/// desks change it by 10 dB or more), so this is a hot/cold meter, not a
/// range finder.
abstract final class ProximityMeter {
  /// Signal at or below this is 0 % (far / barely heard).
  static const double coldRssi = -95;

  /// Signal at or above this is 100 % (within arm's reach).
  static const double hotRssi = -45;

  /// Linear map of [rssi] from [coldRssi]..[hotRssi] to 0..100, clamped.
  static int closenessPercent(double rssi) {
    final fraction = (rssi - coldRssi) / (hotRssi - coldRssi);
    return (fraction.clamp(0.0, 1.0) * 100).round();
  }
}

/// "Best so far": the highest closeness seen since the last [reset].
class PeakHold {
  int? _percent;
  double? _rssi;

  int? get percent => _percent;
  double? get rssi => _rssi;

  /// Returns true when [percent] is a new peak.
  bool add(int percent, double rssi) {
    final current = _percent;
    if (current != null && percent <= current) return false;
    _percent = percent;
    _rssi = rssi;
    return true;
  }

  void reset() {
    _percent = null;
    _rssi = null;
  }
}

/// Vibration band for a closeness value: stronger and more frequent pulses
/// as the target gets closer.
enum HapticBand {
  none(null, null),
  light(HapticStrength.light, Duration(milliseconds: 1400)),
  medium(HapticStrength.medium, Duration(milliseconds: 800)),
  heavy(HapticStrength.heavy, Duration(milliseconds: 400));

  const HapticBand(this.strength, this.interval);

  final HapticStrength? strength;

  /// Minimum time between two pulses in this band.
  final Duration? interval;

  static HapticBand fromCloseness(int percent) {
    if (percent >= 75) return HapticBand.heavy;
    if (percent >= 50) return HapticBand.medium;
    if (percent >= 25) return HapticBand.light;
    return HapticBand.none;
  }
}

/// Rate-limits haptic pulses: packets arrive 10–30 times a second, pulses
/// follow the band's interval instead.
class HapticPulseLimiter {
  DateTime? _lastPulseAt;

  /// The strength to pulse with now, or null when no pulse is due.
  HapticStrength? next(int percent, DateTime now) {
    final band = HapticBand.fromCloseness(percent);
    final interval = band.interval;
    if (interval == null) return null;
    final last = _lastPulseAt;
    if (last != null && now.difference(last) < interval) return null;
    _lastPulseAt = now;
    return band.strength;
  }

  void reset() => _lastPulseAt = null;
}
