import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/view/action_entry_screen.dart';
import 'package:exam_guard/features/dashboard/view/dashboard_screen.dart';
import 'package:exam_guard/features/hall/view/hall_scan_screen.dart';
import 'package:exam_guard/features/hall/view/hall_screen.dart';
import 'package:exam_guard/features/history/view/history_screen.dart';
import 'package:exam_guard/features/lens_finder/view/lens_finder_screen.dart';
import 'package:exam_guard/features/magnetic/view/magnetic_scanner_screen.dart';
import 'package:exam_guard/features/radar/view/seat_sweep_screen.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/radar/view/walk_finder_screen.dart';
import 'package:exam_guard/features/report/view/report_summary_screen.dart';
import 'package:exam_guard/features/rf_detector/view/rf_detector_screen.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/wireless_scanner_screen.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view/session_setup_screen.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// App navigation. Redirects ([appRedirect]) keep the user on a screen that
/// matches the exam state; a running exam always resumes on the dashboard
/// (also after a restart).
final appRouterProvider = Provider<GoRouter>((ref) {
  // Refresh only when the redirect outcome can change. A refresh on every
  // session edit (e.g. a logged incident) rebuilds pushed pages, so their
  // pop no longer closes them.
  final sessionChanges = ValueNotifier<int>(0);
  ref.listen(
    sessionViewModelProvider.select((s) => (s != null, s?.isActive)),
    (_, _) => sessionChanges.value++,
  );
  ref.onDispose(sessionChanges.dispose);

  final router = GoRouter(
    initialLocation: AppRoute.sessionSetup,
    refreshListenable: sessionChanges,
    redirect: (context, state) => appRedirect(
      session: ref.read(sessionViewModelProvider),
      path: state.uri.path,
    ),
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
        path: AppRoute.walkFinder,
        builder: (context, state) => WalkFinderScreen(
          devices: switch (state.extra) {
            final List<ScannedDeviceModel> devices => devices,
            final List<Object?> items =>
              items.whereType<ScannedDeviceModel>().toList(),
            final ScannedDeviceModel device => [device],
            _ => const [],
          },
        ),
      ),
      GoRoute(
        path: AppRoute.seatSweep,
        builder: (context, state) => SeatSweepScreen(
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
      GoRoute(
        path: AppRoute.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoute.hall,
        builder: (context, state) => const HallScreen(),
      ),
      GoRoute(
        path: AppRoute.hallScan,
        builder: (context, state) => const HallScanScreen(),
      ),
      GoRoute(
        path: AppRoute.lensFinder,
        builder: (context, state) => const LensFinderScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Where [path] must be redirected for the current [session], or null to
/// allow it.
/// - a running exam owns the app: setup and history lead to its dashboard
///   (history could otherwise swap the running exam for an old one),
/// - exam screens need a running exam,
/// - the report needs a session (running, just ended or opened from history).
String? appRedirect({required SessionModel? session, required String path}) {
  final running = session != null && session.isActive;

  if ((path == AppRoute.sessionSetup || path == AppRoute.history) && running) {
    return AppRoute.dashboard;
  }
  if (AppRoute.requireActiveSession.contains(path) && !running) {
    return session != null ? AppRoute.report : AppRoute.sessionSetup;
  }
  if (path == AppRoute.report && session == null) {
    return AppRoute.sessionSetup;
  }
  return null;
}

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
