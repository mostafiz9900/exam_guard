enum MagneticHazardLevel {
  normal,
  elevated,
  critical,
  strongSource;

  String get label {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'NORMAL AMBIENT FIELD';
      case MagneticHazardLevel.elevated:
        return 'METAL / ANOMALY DETECTED';
      case MagneticHazardLevel.critical:
        return 'STRONG MAGNETIC ANOMALY';
      case MagneticHazardLevel.strongSource:
        return 'VERY STRONG SOURCE — DEVICE AT CONTACT RANGE';
    }
  }

  String get suggestion {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'No metallic or magnetic anomalies nearby.';
      case MagneticHazardLevel.elevated:
        return 'Suspected hidden metal / earpiece magnet. Check clothing pockets or seat.';
      case MagneticHazardLevel.critical:
        return 'Strong field change. A phone, smartwatch or speaker magnet is likely very close.';
      case MagneticHazardLevel.strongSource:
        return 'Field is far above normal. An electronic device or magnet is touching the phone area — inspect now.';
    }
  }
}

enum MagneticSensitivity {
  high(55.0, 'HIGH (0.5m Detect)'),
  balanced(72.0, 'BALANCED (1.0m Detect)'),
  extreme(100.0, 'HIGH METAL (1.5m Detect)');

  const MagneticSensitivity(this.threshold, this.label);
  final double threshold;
  final String label;
}
