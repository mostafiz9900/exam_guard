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

  /// Routes that only make sense while an exam is running.
  static const Set<String> requireActiveSession = {
    dashboard,
    scanner,
    radar,
    magnetic,
    rfDetector,
    actionNew,
  };
}
