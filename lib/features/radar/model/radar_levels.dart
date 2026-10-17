/// Proximity band derived from the estimated distance to the target.
enum ThreatLevel {
  critical,
  high,
  medium,
  low;

  /// Upper distance bound of each band, in metres.
  static const double criticalWithin = 1.5;
  static const double highWithin = 3.5;
  static const double mediumWithin = 6.0;

  static ThreatLevel fromDistance(double meters) {
    if (meters <= criticalWithin) return ThreatLevel.critical;
    if (meters <= highWithin) return ThreatLevel.high;
    if (meters <= mediumWithin) return ThreatLevel.medium;
    return ThreatLevel.low;
  }

  /// English label, used in saved incident records (official record).
  String get label {
    switch (this) {
      case ThreatLevel.critical:
        return 'CRITICAL PROXIMITY';
      case ThreatLevel.high:
        return 'HIGH PROXIMITY';
      case ThreatLevel.medium:
        return 'MODERATE PROXIMITY';
      case ThreatLevel.low:
        return 'LOW / DISTANT SIGNAL';
    }
  }

  /// Translation key for the on-screen label.
  String get labelKey => 'radar_threat_$name';

  /// Translation key for the on-screen description.
  String get descriptionKey => 'radar_threat_${name}_desc';
}

enum ProximityTrend {
  approaching(true),
  receding(false),
  stationary(null);

  const ProximityTrend(this.isCloser);
  final bool? isCloser;

  /// Translation key for the on-screen label.
  String get labelKey => 'radar_trend_$name';

  /// Translation key for what the inspector should do next.
  String get instructionKey => 'radar_trend_${name}_hint';
}
