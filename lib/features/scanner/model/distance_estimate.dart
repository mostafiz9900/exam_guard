import 'dart:math' as math;

/// Rough distance to a BLE transmitter from its signal strength
/// (log-distance path loss). Bodies, desks and walls change RSSI by 10 dB or
/// more, so the result is ±50 % at best: show it rounded and marked "≈",
/// never as a precise range.
abstract final class DistanceEstimate {
  /// Typical RSSI of a phone-class transmitter at 1 m.
  static const int defaultRssiAt1m = -59;

  /// Indoor path-loss exponent.
  static const double defaultPathLoss = 2.5;

  /// Expected RSSI at 1 m. The BLE TX Power Level is measured at 0 m, and
  /// free-space loss over the first metre at 2.4 GHz is about 41 dB.
  static int rssiAt1m(int? txPower) {
    if (txPower == null || txPower < -30 || txPower > 20) {
      return defaultRssiAt1m;
    }
    return txPower - 41;
  }

  /// Estimated distance in metres for [rssi].
  static double meters(
    num rssi, {
    int rssiAt1m = defaultRssiAt1m,
    double n = defaultPathLoss,
  }) {
    final ratio = (rssiAt1m - rssi) / (10 * n);
    return math.pow(10, ratio).toDouble();
  }

  /// [meters] using the device's advertised TX power when it has one.
  static double forDevice(num rssi, int? txPower) =>
      meters(rssi, rssiAt1m: rssiAt1m(txPower));
}
