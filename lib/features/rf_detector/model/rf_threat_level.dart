enum RfThreatLevel {
  quiet('QUIET (below -70 dBm)'),
  moderate('ACTIVE TRANSMITTER NEARBY (-70 to -50 dBm)'),
  strong('STRONG TRANSMITTER VERY CLOSE (above -50 dBm)');

  const RfThreatLevel(this.label);

  /// English label, used in saved incident records (official record).
  final String label;

  /// Translation key for the on-screen label.
  String get labelKey => 'rf_level_$name';

  /// Translation key for the on-screen suggestion.
  String get suggestionKey => 'rf_level_${name}_hint';

  static RfThreatLevel fromDbm(double? dbm) {
    if (dbm == null || dbm <= -70) return RfThreatLevel.quiet;
    if (dbm <= -50) return RfThreatLevel.moderate;
    return RfThreatLevel.strong;
  }
}
