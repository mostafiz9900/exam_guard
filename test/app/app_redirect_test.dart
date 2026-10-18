import 'package:exam_guard/app/app_router.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 10, 18, 9);

final _running = SessionModel(
  id: '1',
  instituteName: '',
  teacherName: '',
  roomNumber: '12',
  startTime: _start,
);

final _ended = _running.copyWith(endTime: _start.add(const Duration(hours: 2)));

void main() {
  group('history route', () {
    test('is open when no exam is running', () {
      expect(appRedirect(session: null, path: AppRoute.history), isNull);
      expect(appRedirect(session: _ended, path: AppRoute.history), isNull);
    });

    test('sends a running exam back to its dashboard', () {
      expect(
        appRedirect(session: _running, path: AppRoute.history),
        AppRoute.dashboard,
      );
    });
  });

  test('a report opened from history is reachable', () {
    expect(appRedirect(session: _ended, path: AppRoute.report), isNull);
    expect(
      appRedirect(session: null, path: AppRoute.report),
      AppRoute.sessionSetup,
    );
  });

  test('existing rules still hold', () {
    expect(
      appRedirect(session: _running, path: AppRoute.sessionSetup),
      AppRoute.dashboard,
    );
    expect(
      appRedirect(session: _ended, path: AppRoute.dashboard),
      AppRoute.report,
    );
    expect(
      appRedirect(session: null, path: AppRoute.scanner),
      AppRoute.sessionSetup,
    );
    expect(appRedirect(session: _running, path: AppRoute.radar), isNull);
    expect(appRedirect(session: null, path: AppRoute.sessionSetup), isNull);
  });
}
