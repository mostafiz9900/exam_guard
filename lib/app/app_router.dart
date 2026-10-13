import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/view/action_entry_screen.dart';
import 'package:exam_guard/features/dashboard/view/dashboard_screen.dart';
import 'package:exam_guard/features/magnetic/view/magnetic_scanner_screen.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/report/view/report_summary_screen.dart';
import 'package:exam_guard/features/rf_detector/view/rf_detector_screen.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/wireless_scanner_screen.dart';
import 'package:exam_guard/features/session/view/session_setup_screen.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// App navigation. Redirects keep the user on a screen that matches the
/// exam state:
/// - a running exam always resumes on the dashboard (also after a restart),
/// - exam screens are unreachable without a running exam,
/// - the report needs a session (running or just ended).
final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionChanges = ValueNotifier<int>(0);
  ref.listen(sessionViewModelProvider, (_, _) => sessionChanges.value++);
  ref.onDispose(sessionChanges.dispose);

  final router = GoRouter(
    initialLocation: AppRoute.sessionSetup,
    refreshListenable: sessionChanges,
    redirect: (context, state) {
      final session = ref.read(sessionViewModelProvider);
      final running = session != null && session.isActive;
      final path = state.uri.path;

      if (path == AppRoute.sessionSetup && running) return AppRoute.dashboard;
      if (AppRoute.requireActiveSession.contains(path) && !running) {
        return session != null ? AppRoute.report : AppRoute.sessionSetup;
      }
      if (path == AppRoute.report && session == null) {
        return AppRoute.sessionSetup;
      }
      return null;
    },
    errorBuilder: (context, state) => const _UnknownRoute(),
    routes: [
      GoRoute(
        path: AppRoute.sessionSetup,
        builder: (context, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: AppRoute.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoute.scanner,
        builder: (context, state) => const WirelessScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.radar,
        builder: (context, state) => TrackingRadarScreen(
          targetDevice: state.extra is ScannedDeviceModel
              ? state.extra! as ScannedDeviceModel
              : null,
        ),
      ),
      GoRoute(
        path: AppRoute.magnetic,
        builder: (context, state) => const MagneticScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.rfDetector,
        builder: (context, state) => const RfDetectorScreen(),
      ),
      GoRoute(
        path: AppRoute.actionNew,
        builder: (context, state) => ActionEntryScreen(
          args: switch (state.extra) {
            final ActionEntryArgs args => args,
            final ScannedDeviceModel device => ActionEntryArgs(device: device),
            _ => const ActionEntryArgs(),
          },
        ),
      ),
      GoRoute(
        path: AppRoute.report,
        builder: (context, state) => const ReportSummaryScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Unknown links fall back to the right home screen via the redirect.
class _UnknownRoute extends StatelessWidget {
  const _UnknownRoute();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => GoRouter.of(context).go(AppRoute.sessionSetup),
    );
    return const SizedBox.shrink();
  }
}
