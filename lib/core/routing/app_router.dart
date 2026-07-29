import 'package:go_router/go_router.dart';

import '../../features/scanner/presentation/wireless_scanner_screen.dart';
import '../../features/scanner/presentation/magnetic_scanner_screen.dart';
import '../../features/radar/presentation/tracking_radar_screen.dart';
import '../../features/action_log/presentation/action_entry_screen.dart';
import '../../features/report/presentation/report_summary_screen.dart';
import '../../features/session/presentation/session_setup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

/// Central router for ExamGuard.
///
/// This router keeps navigation decoupled from UI and supports future feature routes.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoute.sessionSetup,
    routes: [
      GoRoute(
        path: AppRoute.sessionSetup,
        name: AppRoute.sessionSetupName,
        builder: (context, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: AppRoute.dashboard,
        name: AppRoute.dashboardName,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoute.scanner,
        name: AppRoute.scannerName,
        builder: (context, state) => const WirelessScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.radar,
        name: AppRoute.radarName,
        builder: (context, state) => const TrackingRadarScreen(),
      ),
      GoRoute(
        path: AppRoute.magnetic,
        name: AppRoute.magneticName,
        builder: (context, state) => const MagneticScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.report,
        name: AppRoute.reportName,
        builder: (context, state) => const ReportSummaryScreen(),
      ),
      GoRoute(
        path: AppRoute.actionNew,
        name: AppRoute.actionNewName,
        builder: (context, state) => const ActionEntryScreen(),
      ),
    ],
  );
}

class AppRoute {
  AppRoute._();

  static const String dashboard = '/dashboard';
  static const String dashboardName = 'dashboard';
  static const String sessionSetup = '/';
  static const String sessionSetupName = 'session_setup';
  static const String scanner = '/scanner';
  static const String scannerName = 'scanner';
  static const String radar = '/radar';
  static const String radarName = 'radar';
  static const String magnetic = '/magnetic';
  static const String magneticName = 'magnetic';
  static const String actionNew = '/action/new';
  static const String actionNewName = 'action_new';
  static const String report = '/report';
  static const String reportName = 'report';
}
