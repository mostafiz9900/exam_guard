import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/radar/view/seat_sweep_screen.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/radar/view/walk_finder_screen.dart';
import 'package:exam_guard/features/radar/view_model/seat_sweep_view_model.dart';
import 'package:exam_guard/features/radar/view_model/walk_finder_view_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

import 'finder_fakes.dart';

class _KeysOnlyLoader extends AssetLoader {
  const _KeysOnlyLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

class _FakeSession extends SessionViewModel {
  @override
  SessionModel? build() => SessionModel(
    id: 's1',
    instituteName: 'School',
    teacherName: 'T',
    roomNumber: '12',
    startTime: DateTime(2026),
    seatRows: 6,
    seatCols: 8,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen,
  FakeFinderBluetooth bluetooth,
) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      // Keys only: assertions do not depend on the wording.
      assetLoader: const _KeysOnlyLoader(),
      child: ProviderScope(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(bluetooth),
          wakelockServiceProvider.overrideWithValue(FakeWakelock()),
          hapticServiceProvider.overrideWithValue(FakeHaptics()),
          sessionViewModelProvider.overrideWith(_FakeSession.new),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp(
              theme: AppTheme.darkTheme,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: screen,
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 40 && find.byWidget(screen).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
  return ProviderScope.containerOf(tester.element(find.byWidget(screen)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('walk finder renders, starts and highlights a close target', (
    tester,
  ) async {
    final bluetooth = FakeFinderBluetooth();
    final screen = WalkFinderScreen(
      devices: [bleDevice('AA'), bleDevice('BB')],
    );
    final container = await _pump(tester, screen, bluetooth);
    expect(find.text('walk_title'), findsOneWidget);
    await tester.tap(find.text('walk_start'));
    await tester.pump();
    expect(bluetooth.owners, {'walk_finder'});
    final now = DateTime.now();
    for (var i = 0; i < 20; i++) {
      container
          .read(walkFinderViewModelProvider.notifier)
          .onSignal('AA', -50, now.add(Duration(milliseconds: 100 * i)));
    }
    await tester.pump();
    expect(find.text('walk_very_close'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('seat sweep renders the grid and the most likely seat', (
    tester,
  ) async {
    final bluetooth = FakeFinderBluetooth();
    final screen = SeatSweepScreen(targetDevice: bleDevice('AA'));
    final container = await _pump(tester, screen, bluetooth);
    final vm = container.read(seatSweepViewModelProvider.notifier);
    expect(find.text('C4'), findsOneWidget);
    await tester.tap(find.text('C4'));
    await tester.pump();
    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      vm.onSignal(-52, now.add(Duration(milliseconds: 100 * i)));
    }
    vm.finishSample();
    await tester.pump();
    expect(find.text('sweep_most_likely'), findsOneWidget);
    expect(find.text('sweep_log_at_seat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('radar shows the closeness meter', (tester) async {
    final bluetooth = FakeFinderBluetooth();
    final screen = TrackingRadarScreen(targetDevice: bleDevice('AA'));
    await _pump(tester, screen, bluetooth);
    expect(find.text('--'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
