/// Why a finder screen (walk finder, seat sweep) is not receiving signals.
enum FinderScanIssue {
  /// Android delivers no Bluetooth results while Location is off. The scan
  /// resumes by itself once Location is back on.
  locationOff,

  /// Bluetooth is switched off (or not allowed).
  bluetoothOff,

  /// Android paused scanning after too many restarts (~30 s).
  throttled,

  /// The scan could not start or stopped with an error.
  failed;

  String get _keyStem => switch (this) {
    FinderScanIssue.locationOff => 'walk_issue_location_off',
    FinderScanIssue.bluetoothOff => 'walk_issue_bluetooth_off',
    FinderScanIssue.throttled => 'walk_issue_throttled',
    FinderScanIssue.failed => 'walk_issue_failed',
  };

  /// Translation key of the short title.
  String get titleKey => '${_keyStem}_title';

  /// Translation key of what to do about it.
  String get textKey => '${_keyStem}_text';
}
