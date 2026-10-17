import 'package:flutter/material.dart';

/// Signal strength bands used everywhere on the dashboard.
///
/// A stronger (higher) RSSI means the device is closer, which is the more
/// suspicious case in an exam hall — so strong is red, weak is neutral.
class SignalStrength {
  SignalStrength._();

  /// RSSI above this (dBm) counts as a strong, close-range signal.
  static const int strongRssi = -65;

  /// RSSI above this (dBm) counts as a medium-range signal.
  static const int mediumRssi = -75;

  static bool isStrong(int rssi) => rssi > strongRssi;

  static Color color(int rssi, ColorScheme colors) {
    if (rssi > strongRssi) return Colors.red;
    if (rssi > mediumRssi) return Colors.orange;
    return colors.onSurfaceVariant;
  }
}
