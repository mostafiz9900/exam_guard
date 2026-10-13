enum ThreatLevel {
  critical,
  high,
  medium,
  low;

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

  String get description {
    switch (this) {
      case ThreatLevel.critical:
        return 'Target is within 1.5 meters. High risk of active transmission.';
      case ThreatLevel.high:
        return 'Target is within 1.5 - 3.5 meters of inspector.';
      case ThreatLevel.medium:
        return 'Target is within 3.5 - 6 meters range.';
      case ThreatLevel.low:
        return 'Target signal is weak or far away (>6 meters).';
    }
  }
}

enum ProximityTrend {
  approaching(
    'APPROACHING TARGET (GETTING CLOSER)',
    'Distance decreasing! Step forward towards candidate.',
    true,
  ),
  receding(
    'RECEDING (MOVING AWAY)',
    'Distance increasing! Turn 180° around or change aisle.',
    false,
  ),
  stationary(
    'STATIONARY LOCK (HOLD POSITION)',
    'Distance locked (±0.2m). Sweep phone left/right to pinpoint desk.',
    null,
  );

  const ProximityTrend(this.label, this.instruction, this.isCloser);
  final String label;
  final String instruction;
  final bool? isCloser;
}
