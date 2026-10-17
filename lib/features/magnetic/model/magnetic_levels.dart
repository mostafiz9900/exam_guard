enum MagneticHazardLevel {
  normal,
  elevated,
  critical,
  strongSource;

  /// English label, used in saved incident records (official record).
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

  /// Translation key for the on-screen label.
  String get labelKey => 'mag_level_$_keyName';

  /// Translation key for the on-screen suggestion.
  String get suggestionKey => 'mag_level_${_keyName}_hint';

  String get _keyName =>
      this == MagneticHazardLevel.strongSource ? 'strong_source' : name;
}

/// How large a change from the calibrated baseline counts as an anomaly.
/// A phone magnetometer only sees small magnets/devices within a few cm,
/// so every preset assumes the phone is held within ~5 cm of the item.
/// Higher sensitivity = lower threshold.
enum MagneticSensitivity {
  low(35.0, 'Low sensitivity'),
  medium(20.0, 'Medium sensitivity'),
  high(10.0, 'High sensitivity');

  const MagneticSensitivity(this.threshold, this.label);

  /// Change from baseline (μT) above which the field is "elevated".
  /// Critical is above 2×, very strong source above 4×.
  final double threshold;

  /// English label, used in saved incident records (official record).
  final String label;

  /// Translation key for the on-screen label.
  String get labelKey => 'mag_sensitivity_$name';

  /// English chip text, used in saved incident records.
  String get chipLabel => '$label (±${threshold.toStringAsFixed(0)} μT)';
}
