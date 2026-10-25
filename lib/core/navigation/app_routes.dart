/// Every route path in the app. Navigate with these, never string literals.
class AppRoute {
  AppRoute._();

  static const String sessionSetup = '/';
  static const String dashboard = '/dashboard';
  static const String scanner = '/scanner';
  static const String radar = '/radar';
  static const String magnetic = '/magnetic';
  static const String rfDetector = '/rf-detector';
  static const String actionNew = '/action/new';
  static const String report = '/report';

  /// Hands-free finder: vibrates when the inspector walks near any of the
  /// chosen devices. `extra` is a `List<ScannedDeviceModel>`.
  static const String walkFinder = '/walk-finder';

  /// Seat sweep: record a device's signal at each seat to find the strongest
  /// seat. `extra` is a `ScannedDeviceModel`.
  static const String seatSweep = '/seat-sweep';

  /// Past exams. Only reachable while no exam is running (opening an old
  /// report would otherwise replace the running exam in memory).
  static const String history = '/history';

  /// Shared hall: several invigilator phones and ESP32 sensor nodes.
  static const String hall = '/hall';

  /// Scans a hall QR code; pops with its text.
  static const String hallScan = '/hall/scan';

  /// Routes that only make sense while an exam is running.
  static const Set<String> requireActiveSession = {
    dashboard,
    scanner,
    radar,
    magnetic,
    rfDetector,
    actionNew,
    walkFinder,
    seatSweep,
    hall,
    hallScan,
  };
}
