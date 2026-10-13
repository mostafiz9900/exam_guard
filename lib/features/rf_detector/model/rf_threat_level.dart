enum RfThreatLevel {
  quiet(
    'QUIET (below -70 dBm)',
    'No strong 2.4 GHz transmitter near the phone.',
  ),
  moderate(
    'ACTIVE TRANSMITTER NEARBY (-70 to -50 dBm)',
    'A Bluetooth transmitter is within a few metres. Sweep slowly to find it.',
  ),
  strong(
    'STRONG TRANSMITTER VERY CLOSE (above -50 dBm)',
    'A transmitting device is within about 1 metre. Inspect this desk.',
  );

  const RfThreatLevel(this.label, this.suggestion);
  final String label;
  final String suggestion;

  static RfThreatLevel fromDbm(double? dbm) {
    if (dbm == null || dbm <= -70) return RfThreatLevel.quiet;
    if (dbm <= -50) return RfThreatLevel.moderate;
    return RfThreatLevel.strong;
  }
}
