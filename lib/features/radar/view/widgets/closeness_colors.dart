import 'package:flutter/material.dart';

import 'package:exam_guard/features/radar/model/radar_levels.dart';

/// Cold → hot stops shared by every finder (gauge, bars, seat heat map).
/// Mid-saturation hues that stay visible on light and dark surfaces.
const List<Color> closenessStops = [
  Color(0xFF3B82F6), // blue
  Color(0xFF06B6D4), // cyan
  Color(0xFFF59E0B), // amber
  Color(0xFFF97316), // orange
  Color(0xFFEF4444), // red
];

/// Cold blue → hot red for a 0–100 closeness value.
Color closenessColor(int percent) => closenessColorAt(percent / 100);

/// Same as [closenessColor] for a 0.0–1.0 fraction (smooth while animating).
Color closenessColorAt(double fraction) {
  final t = fraction.clamp(0.0, 1.0) * (closenessStops.length - 1);
  final i = t.floor().clamp(0, closenessStops.length - 2);
  return Color.lerp(closenessStops[i], closenessStops[i + 1], t - i)!;
}

/// [color] adjusted to stay readable as text/icon ink on the current
/// surface: darker on light themes, a touch lighter on dark ones.
Color readableInk(BuildContext context, Color color) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? Color.lerp(color, Colors.white, 0.12)!
      : Color.lerp(color, Colors.black, 0.3)!;
}

/// Accent of the warmer / colder / hold-still trend pill.
Color trendColor(ProximityTrend trend, ColorScheme colors) => switch (trend) {
  ProximityTrend.approaching => closenessStops[3],
  ProximityTrend.receding => closenessStops[0],
  ProximityTrend.stationary => colors.onSurfaceVariant,
};

/// Representative colour of a distance band (cold for far, hot for near).
Color threatColor(ThreatLevel level) => switch (level) {
  ThreatLevel.critical => closenessColor(92),
  ThreatLevel.high => closenessColor(70),
  ThreatLevel.medium => closenessColor(45),
  ThreatLevel.low => closenessColor(10),
};
