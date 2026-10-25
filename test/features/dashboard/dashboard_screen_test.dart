// Dashboard screen on a small phone: renders in light and dark, every
// module card navigates to its route, not-measuring states never look like
// "all clear", live stats follow the scanner/magnetometer, new-device
// alerts, End Exam (confirm, save, report), back-button exit dialog and the
// appearance/language menu.
//
// No hardware: the scanner and magnetometer view models are replaced by
// fakes with a settable state; the session uses the real view model on an
// in-memory storage.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/settings/theme_mode_view_model.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/dashboard_screen.dart';
import 'package:exam_guard/features/dashboard/view/widgets/dashboard_module_card.dart';
import 'package:exam_guard/features/dashboard/view/widgets/live_stat_badge.dart';
import 'package:exam_guard/features/dashboard/view/widgets/live_threat_tile.dart';
import 'package:exam_guard/features/dashboard/view/widgets/mini_sweep_painter.dart';
import 'package:exam_guard/features/dashboard/view/widgets/room_baseline_card.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes --

class _MemoryStorage implements ILocalStorage {
  final values = <String, Object?>{};
  bool failWrites = false;

  @override
  Future<void> write(String key, Object? value) async {
    if (failWrites) throw Exception('disk full');
    values[key] = value;
  }

  @override
  T? read<T>(String key) {
    final v = values[key];
    return v is T ? v : null;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Iterable<String> get keys => values.keys;

  @override
  Future<void> dispose() async {}
}

/// Scanner with a settable state and no radios.
class _FakeScanner extends ScannerViewModel {
  _FakeScanner(this.initial);

  final ScannerState initial;
  int locationSettingsOpened = 0;
  final acknowledged = <String>[];
  var acknowledgedAll = false;

  @override
  ScannerState build() => initial;

  void emit(ScannerState next) => state = next;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;

  @override
  void acknowledgeAlert(String deviceId) => acknowledged.add(deviceId);

  @override
  void acknowledgeAll() => acknowledgedAll = true;
}

/// Magnetometer with a settable state and no sensor.
class _FakeMagnetic extends MagneticViewModel {
  _FakeMagnetic(this.initial);

  final MagneticState initial;

  @override
  MagneticState build() => initial;

  void emit(MagneticState next) => state = next;
}

// --------------------------------------------------------------- fixtures --

final _start = DateTime(2026, 10, 18, 9);

SessionModel _session({String room = '302-B'}) => SessionModel(
  id: 's1',
  instituteName: 'Dhaka Residential Model College — Main Examination Hall',
  teacherName: 'T',
  roomNumber: room,
  startTime: _start,
);

_MemoryStorage _storageWith(SessionModel? session, {ThemeMode? theme}) {
  final storage = _MemoryStorage();
  if (session != null) {
    storage.values['session_${session.id}'] = session.toJson();
    storage.values['current_session_id'] = session.id;
    storage.values['last_session_id'] = session.id;
  }
  if (theme != null) storage.values[ThemeModeViewModel.storageKey] = theme.name;
  return storage;
}

ScannedDeviceModel _device(String id, int rssi, {String? name}) =>
    ScannedDeviceModel(
      id: id,
      name: name ?? 'Device $id',
      rssi: rssi,
      lastSeen: _start,
      firstSeen: _start,
    );

NewDeviceAlert _alert(String id, String name) => NewDeviceAlert(
  deviceId: id,
  displayName: name,
  deviceType: 'Smart Earpiece / Audio',
  transport: DeviceTransport.ble,
  rssi: -58,
  detectedAt: _start.add(const Duration(minutes: 30)),
);

const _liveMagnetic = MagneticState(
  isScanning: true,
  isHardwareSensorActive: true,
  magnitude: 48.26,
  baseline: 48,
);

const _noSensor = MagneticState(errorKey: MagneticViewModel.noSensorErrorKey);

// ---------------------------------------------------------------- harness --

class _Harness {
  _Harness(this.scanner, this.magnetic, this.storage, this.router);

  final _FakeScanner scanner;
  final _FakeMagnetic magnetic;
  final _MemoryStorage storage;
  final GoRouter router;

  /// Every route pushed/gone to after the dashboard, with its `extra`.
  final visits = <(String, Object?)>[];

  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  ScannerState? scanner,
  MagneticState magnetic = _liveMagnetic,
  SessionModel? session,
  bool noSession = false,
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(320, 568),
}) async {
  rootBundle.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fakeScanner = _FakeScanner(scanner ?? ScannerState(isScanning: true));
  final fakeMagnetic = _FakeMagnetic(magnetic);
  final storage = _storageWith(
    noSession ? null : (session ?? _session()),
    theme: theme,
  );

  late _Harness harness;
  GoRoute stub(String path) => GoRoute(
    path: path,
    builder: (context, state) {
      harness.visits.add((path, state.extra));
      return Scaffold(body: Center(child: Text('route:$path')));
    },
  );
  final router = GoRouter(
    initialLocation: AppRoute.dashboard,
    routes: [
      stub(AppRoute.sessionSetup),
      GoRoute(
        path: AppRoute.dashboard,
        builder: (_, _) => const DashboardScreen(),
      ),
      for (final r in [
        AppRoute.scanner,
        AppRoute.radar,
        AppRoute.magnetic,
        AppRoute.rfDetector,
        AppRoute.actionNew,
        AppRoute.report,
      ])
        stub(r),
    ],
  );
  addTearDown(router.dispose);
  harness = _Harness(fakeScanner, fakeMagnetic, storage, router);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          scannerViewModelProvider.overrideWith(() => fakeScanner),
          magneticViewModelProvider.overrideWith(() => fakeMagnetic),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => Consumer(
              builder: (_, ref, _) => MaterialApp.router(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ref.watch(themeModeViewModelProvider),
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: router,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(DashboardScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
  return harness;
}

/// The radar sweep repeats forever, so pumpAndSettle never returns while
/// the dashboard is shown; pump through transitions instead.
Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets real async work (storage writes, locale loading) finish.
Future<void> _async(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Real Roboto metrics instead of the wide test font (as the responsive
/// test and dashboard_alerts_test do).
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String file) async =>
      ByteData.view(File('$dir/$file').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(bytes('Roboto-$f.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(bytes('MaterialIcons-Regular.otf'))).load();
}

Finder _card(String title) => find.widgetWithText(DashboardModuleCard, title);

String _statValue(WidgetTester tester, String title) => tester
    .widget<LiveStatBadge>(find.widgetWithText(LiveStatBadge, title))
    .value;

String _badge(WidgetTester tester, String title) =>
    tester.widget<DashboardModuleCard>(_card(title)).badgeText;

/// Taps [finder] after scrolling it into view.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _frames(tester, 4);
}

// ------------------------------------------------------------------ tests --

void main() {
  final platformCalls = <MethodCall>[];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('layout', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders a live exam on a small phone ($mode)', (
        tester,
      ) async {
        await _pump(
          tester,
          theme: mode,
          scanner: ScannerState(
            isScanning: true,
            devices: [
              _device('AA:01', -50, name: 'Galaxy Buds2 Pro with a long name'),
              _device('AA:02', -70),
              _device('AA:03', -90),
              _device('AA:04', -95),
            ],
            baselineAt: _start,
            trustedIds: const {'x'},
            alerts: [_alert('AA:01', 'Galaxy Buds2 Pro')],
            alertSeq: 1,
          ),
        );
        expect(
          Theme.of(tester.element(find.byType(DashboardScreen))).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(find.text('Room 302-B'), findsOneWidget);
        expect(find.text('MONITORING LIVE'), findsOneWidget);
        expect(find.byType(DashboardModuleCard), findsNWidgets(6));
        // Only the top three devices are listed.
        expect(
          find.byType(LiveThreatTile, skipOffstage: false),
          findsNWidgets(3),
        );

        // Scroll to the bottom: nothing overflows anywhere on the way.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2000),
        );
        await _frames(tester, 3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('long room name and landscape small phone do not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        session: _session(room: 'Auditorium North Wing 12/B Ground Floor'),
        size: const Size(568, 320),
      );
      expect(find.byType(DashboardModuleCard), findsNWidgets(6));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await _frames(tester, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide screen uses a three-column module grid', (tester) async {
      await _pump(tester, size: const Size(800, 1280));
      final cards = find.byType(DashboardModuleCard);
      expect(cards, findsNWidgets(6));
      final firstRowY = tester.getTopLeft(cards.at(0)).dy;
      final perRow = [
        for (var i = 0; i < 6; i++) tester.getTopLeft(cards.at(i)).dy,
      ].where((y) => y == firstRowY).length;
      expect(perRow, 3);
      expect(tester.takeException(), isNull);
    });

    // Regression: card content scales with screen width, so a fixed aspect
    // ratio overflowed every card in the 3-column grid (> 650 px wide).
    for (final size in const [
      Size(768, 1024),
      Size(800, 1280),
      Size(800, 360),
      Size(1280, 800),
    ]) {
      testWidgets(
        'module grid does not overflow at ${size.width.toInt()}x'
        '${size.height.toInt()}',
        (tester) async {
          await _pump(tester, size: size);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('without a running exam shows "No active session" and no '
        'End exam button', (tester) async {
      await _pump(tester, noSession: true);
      expect(find.text('No active session'), findsOneWidget);
      expect(find.text('End exam'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    final cards = {
      'Wireless scan': AppRoute.scanner,
      'Tracking radar': AppRoute.radar,
      'Magnetic scan': AppRoute.magnetic,
      'Report': AppRoute.report,
      'RF activity meter': AppRoute.rfDetector,
      'Log incident': AppRoute.actionNew,
    };
    for (final MapEntry(key: title, value: route) in cards.entries) {
      testWidgets('"$title" card pushes $route', (tester) async {
        final h = await _pump(tester);
        await _tapVisible(tester, _card(title));
        expect(h.location, route);
        expect(find.text('route:$route'), findsOneWidget);
        // Pushed, not replaced: back returns to the dashboard.
        expect(h.router.canPop(), isTrue);
        h.router.pop();
        await _frames(tester, 6);
        expect(find.byType(DashboardScreen), findsOneWidget);
      });
    }

    testWidgets('stat badges open the scanner and magnetic screens', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(LiveStatBadge, 'Wireless signals'),
      );
      expect(h.location, AppRoute.scanner);
      h.router.pop();
      await _frames(tester, 6);

      await _tapVisible(
        tester,
        find.widgetWithText(LiveStatBadge, 'Strong signals'),
      );
      expect(h.location, AppRoute.scanner);
      h.router.pop();
      await _frames(tester, 6);

      await _tapVisible(
        tester,
        find.widgetWithText(LiveStatBadge, 'Magnetic field'),
      );
      expect(h.location, AppRoute.magnetic);
    });

    testWidgets('app bar scanner icon and "View scanner" open the scanner', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(find.byTooltip('Scanner active'), findsOneWidget);
      await tester.tap(find.byTooltip('Scanner active'));
      await _frames(tester, 4);
      expect(h.location, AppRoute.scanner);
      h.router.pop();
      await _frames(tester, 6);

      await _tapVisible(tester, find.text('View scanner'));
      expect(h.location, AppRoute.scanner);
    });

    testWidgets('Track on a live device opens the radar with that device', (
      tester,
    ) async {
      final target = _device('AA:01', -50, name: 'Galaxy Buds2 Pro');
      final h = await _pump(
        tester,
        scanner: ScannerState(isScanning: true, devices: [target]),
      );
      await _tapVisible(
        tester,
        find.descendant(
          of: find.byType(LiveThreatTile),
          matching: find.text('Track'),
        ),
      );
      expect(h.location, AppRoute.radar);
      expect(h.visits.last, (AppRoute.radar, target));
    });
  });

  group('not measuring never looks like all clear', () {
    void expectNoAllClear() {
      expect(find.text('MONITORING LIVE'), findsNothing);
      expect(find.text('Scanning for devices…'), findsNothing);
      expect(find.byTooltip('Scanner active'), findsNothing);
      expect(
        find
            .byType(CustomPaint)
            .evaluate()
            .where(
              (e) => (e.widget as CustomPaint).painter is MiniSweepPainter,
            ),
        isEmpty,
      );
    }

    testWidgets('Bluetooth off', (tester) async {
      final h = await _pump(
        tester,
        scanner: ScannerState(isScanning: true, isBluetoothOff: true),
      );
      expectNoAllClear();
      expect(find.text('BLUETOOTH OFF'), findsOneWidget);
      expect(find.byTooltip('Scanner not running'), findsOneWidget);
      await tester.ensureVisible(find.text('Open scanner'));
      expect(
        find.text('Bluetooth is off. Turn it on to detect nearby devices.'),
        findsOneWidget,
      );
      // Baseline can't be taken while nothing is measured.
      final take = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(RoomBaselineCard),
          matching: find.byType(FilledButton),
        ),
      );
      expect(take.onPressed, isNull);

      // The status chip leads to the scanner to fix it.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 3000),
      );
      await _frames(tester, 2);
      await tester.tap(find.text('BLUETOOTH OFF'));
      await _frames(tester, 4);
      expect(h.location, AppRoute.scanner);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Location off offers Turn on Location', (tester) async {
      final h = await _pump(
        tester,
        scanner: ScannerState(isScanning: true, isLocationOff: true),
      );
      expectNoAllClear();
      expect(find.text('LOCATION OFF'), findsOneWidget);
      await tester.tap(find.text('LOCATION OFF'));
      await tester.pump();
      expect(h.scanner.locationSettingsOpened, 1);

      final button = find.widgetWithText(FilledButton, 'Turn on Location');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(h.scanner.locationSettingsOpened, 2);
      expect(h.location, AppRoute.dashboard);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scan failed and scan stopped', (tester) async {
      final h = await _pump(
        tester,
        scanner: ScannerState(isScanning: true, errorMessage: 'scan_err_x'),
      );
      expectNoAllClear();
      expect(find.text('SCAN FAILED'), findsOneWidget);

      h.scanner.emit(ScannerState());
      await tester.pump();
      expectNoAllClear();
      expect(find.text('SCAN STOPPED'), findsOneWidget);
      await tester.ensureVisible(find.text('Open scanner'));
      expect(
        find.text(
          'Scanning is stopped. Nearby devices are not being detected.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a transient notice is not a scan failure', (tester) async {
      await _pump(
        tester,
        scanner: ScannerState(isScanning: true, noticeKey: 'connect_failed'),
      );
      expect(find.text('MONITORING LIVE'), findsOneWidget);
      expect(find.text('SCAN FAILED'), findsNothing);
    });

    testWidgets('no magnetometer says "No sensor", never a reading', (
      tester,
    ) async {
      await _pump(tester, magnetic: _noSensor);
      expect(_statValue(tester, 'Magnetic field'), 'No sensor');
      expect(_badge(tester, 'Magnetic scan'), 'Not available');
      expect(find.byIcon(Icons.sensors_off_rounded), findsNWidgets(2));
      expect(find.textContaining('μT'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('magnetometer without a reading shows a dash, not 0 μT', (
      tester,
    ) async {
      await _pump(tester, magnetic: const MagneticState(isScanning: true));
      expect(_statValue(tester, 'Magnetic field'), '—');
      expect(_badge(tester, 'Magnetic scan'), '—');
      expect(find.text('0.0 μT'), findsNothing);
    });
  });

  group('live data', () {
    testWidgets('signal counters and feed follow the scanner', (tester) async {
      final h = await _pump(tester);
      expect(_statValue(tester, 'Wireless signals'), '0');
      expect(_statValue(tester, 'Strong signals'), '0');
      expect(_badge(tester, 'Wireless scan'), '0 active');
      await tester.ensureVisible(find.text('Scanning for devices…'));

      h.scanner.emit(
        ScannerState(
          isScanning: true,
          devices: [
            _device('AA:01', -50), // strong
            _device('AA:02', -64), // strong (> -65)
            _device('AA:03', -65), // not strong (boundary)
            _device('AA:04', -90),
          ],
        ),
      );
      await tester.pump();
      expect(_statValue(tester, 'Wireless signals'), '4');
      expect(_statValue(tester, 'Strong signals'), '2');
      expect(_badge(tester, 'Wireless scan'), '4 active');
      expect(find.text('Scanning for devices…'), findsNothing);
      expect(
        find.byType(LiveThreatTile, skipOffstage: false),
        findsNWidgets(3),
      );
      // Strong signals are shown in the error colour.
      final strong = tester.widget<LiveStatBadge>(
        find.widgetWithText(LiveStatBadge, 'Strong signals'),
      );
      expect(
        strong.color,
        Theme.of(tester.element(find.byType(DashboardScreen)))
            .colorScheme
            .error,
      );

      // Room boundary hides far devices from the counters.
      h.scanner.emit(
        h.scanner.state.copyWith(
          isRoomBoundaryMode: true,
          roomSizePreset: RoomSizePreset.small, // >= -75 dBm
        ),
      );
      await tester.pump();
      expect(_statValue(tester, 'Wireless signals'), '3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('magnetic readout and colour follow the hazard level', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(_statValue(tester, 'Magnetic field'), '48.3 μT');
      expect(_badge(tester, 'Magnetic scan'), '48 μT');
      Color color() => tester
          .widget<LiveStatBadge>(
            find.widgetWithText(LiveStatBadge, 'Magnetic field'),
          )
          .color;
      expect(color(), Colors.teal);

      h.magnetic.emit(
        _liveMagnetic.copyWith(
          magnitude: 75,
          hazardLevel: MagneticHazardLevel.elevated,
        ),
      );
      await tester.pump();
      expect(_statValue(tester, 'Magnetic field'), '75.0 μT');
      expect(color(), Colors.orange);

      h.magnetic.emit(
        _liveMagnetic.copyWith(
          magnitude: 250,
          hazardLevel: MagneticHazardLevel.strongSource,
        ),
      );
      await tester.pump();
      expect(_statValue(tester, 'Magnetic field'), '250.0 μT');
      expect(_badge(tester, 'Magnetic scan'), '250 μT');
      expect(color(), Colors.red);

      // Sensor drops out: back to an honest "No sensor".
      h.magnetic.emit(_noSensor);
      await tester.pump();
      expect(_statValue(tester, 'Magnetic field'), 'No sensor');
    });

    testWidgets('report card counts logged incidents', (tester) async {
      await _pump(tester);
      expect(_badge(tester, 'Report'), '0 logged');
    });
  });

  group('baseline and new-device alerts', () {
    testWidgets('baseline call to action sits above the HUD until taken', (
      tester,
    ) async {
      final h = await _pump(tester);
      final cardTop = tester.getTopLeft(find.byType(RoomBaselineCard)).dy;
      final roomTop = tester.getTopLeft(find.text('Room 302-B')).dy;
      expect(cardTop, lessThan(roomTop));
      expect(find.text('Room baseline'), findsOneWidget);

      h.scanner.emit(
        ScannerState(
          isScanning: true,
          baselineAt: _start,
          trustedIds: const {'a', 'b'},
        ),
      );
      await tester.pump();
      expect(find.text('Room baseline'), findsNothing);
      // Compact line now sits below the HUD.
      expect(
        tester.getTopLeft(find.byType(RoomBaselineCard)).dy,
        greaterThan(tester.getTopLeft(find.text('Room 302-B')).dy),
      );
      expect(find.textContaining('2 trusted'), findsOneWidget);
    });

    testWidgets('new alert shows the banner, buzzes once and opens the sheet', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        scanner: ScannerState(isScanning: true, baselineAt: _start),
      );
      expect(find.byIcon(Icons.notification_important_rounded), findsNothing);

      h.scanner.emit(
        h.scanner.state.copyWith(
          alerts: [_alert('AA:01', 'Galaxy Buds2 Pro')],
          alertSeq: 1,
        ),
      );
      await tester.pump();
      expect(find.text('NEW DEVICE SINCE BASELINE'), findsOneWidget);
      expect(find.text('Galaxy Buds2 Pro'), findsOneWidget);
      expect(
        platformCalls.map((c) => c.method),
        containsAll(['HapticFeedback.vibrate', 'SystemSound.play']),
      );

      // Same alertSeq again (e.g. acknowledgement) does not buzz again.
      platformCalls.clear();
      h.scanner.emit(
        h.scanner.state.copyWith(
          alerts: [
            _alert('AA:01', 'Galaxy Buds2 Pro'),
            _alert('AA:02', 'AirPods Pro'),
          ],
          alertSeq: 1,
        ),
      );
      await tester.pump();
      expect(find.text('2 NEW DEVICES SINCE BASELINE'), findsOneWidget);
      expect(platformCalls, isEmpty);

      await tester.tap(find.text('2 NEW DEVICES SINCE BASELINE'));
      await _frames(tester);
      expect(find.text('New devices (2 unacknowledged)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.done_all_rounded));
      expect(h.scanner.acknowledgedAll, isTrue);
    });

    testWidgets('Log incident in the alerts sheet opens the incident form', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        scanner: ScannerState(
          isScanning: true,
          baselineAt: _start,
          alerts: [_alert('AA:01', 'Galaxy Buds2 Pro')],
          alertSeq: 1,
        ),
      );
      await tester.tap(find.text('NEW DEVICE SINCE BASELINE'));
      await _frames(tester);
      final log = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text('Log incident'),
      );
      await tester.tap(log);
      await _frames(tester);
      expect(h.scanner.acknowledged, ['AA:01']);
      expect(h.location, AppRoute.actionNew);
      expect(tester.takeException(), isNull);
    });
  });

  group('End exam', () {
    testWidgets('Cancel keeps the exam running', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.text('End exam'));
      await _frames(tester, 4);
      expect(find.text('End exam session?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await _frames(tester, 4);
      expect(find.text('End exam session?'), findsNothing);
      expect(h.location, AppRoute.dashboard);
      final saved = SessionModel.fromJson(
        Map<String, dynamic>.from(h.storage.values['session_s1']! as Map),
      );
      expect(saved.isActive, isTrue);
    });

    testWidgets('confirming saves the end time and opens the report', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.text('End exam'));
      await _frames(tester, 4);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'End exam'),
        ),
      );
      await _async(tester);
      await _frames(tester, 6);

      final saved = SessionModel.fromJson(
        Map<String, dynamic>.from(h.storage.values['session_s1']! as Map),
      );
      expect(saved.endTime, isNotNull);
      expect(h.storage.values.containsKey('current_session_id'), isFalse);
      expect(h.location, AppRoute.report);
      // go(), not push(): the dashboard is gone from the stack.
      expect(h.router.canPop(), isFalse);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save stays on the dashboard with an error', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.storage.failWrites = true;
      await tester.tap(find.text('End exam'));
      await _frames(tester, 4);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'End exam'),
        ),
      );
      await _async(tester);
      await _frames(tester, 4);
      expect(
        find.text('Could not end the exam. Please try again.'),
        findsOneWidget,
      );
      expect(h.location, AppRoute.dashboard);
      expect(find.text('End exam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back button asks before leaving; Cancel stays', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.binding.handlePopRoute();
      await _frames(tester, 4);
      expect(find.text('Leave ExamGuard?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await _frames(tester, 4);
      expect(find.text('Leave ExamGuard?'), findsNothing);
      expect(h.location, AppRoute.dashboard);
      expect(
        platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
        isEmpty,
      );
    });

    testWidgets('back button: Minimize leaves the app, exam keeps running', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.binding.handlePopRoute();
      await _frames(tester, 4);
      await tester.tap(find.text('Minimize'));
      await _frames(tester, 4);
      expect(
        platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
      expect(h.location, AppRoute.dashboard);
      final saved = SessionModel.fromJson(
        Map<String, dynamic>.from(h.storage.values['session_s1']! as Map),
      );
      expect(saved.isActive, isTrue);
    });

    testWidgets('back button: End exam needs a second confirmation', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.binding.handlePopRoute();
      await _frames(tester, 4);
      await tester.tap(find.text('End exam…'));
      await _frames(tester, 4);
      expect(find.text('Leave ExamGuard?'), findsNothing);
      expect(find.text('End exam session?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'End exam'),
        ),
      );
      await _async(tester);
      await _frames(tester, 6);
      expect(h.location, AppRoute.report);
    });
  });

  group('settings menu', () {
    testWidgets('switches the theme and remembers it', (tester) async {
      final h = await _pump(tester);
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(DashboardScreen))).brightness;
      expect(brightness(), Brightness.light);

      await tester.tap(find.byTooltip('Appearance'));
      await _frames(tester, 4);
      await tester.tap(find.text('Dark'));
      await _frames(tester, 6);
      expect(brightness(), Brightness.dark);
      expect(h.storage.values[ThemeModeViewModel.storageKey], 'dark');
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches the language to Bangla', (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Appearance'));
      await _frames(tester, 4);
      await tester.tap(find.text('বাংলা'));
      await _async(tester);
      await _frames(tester, 4);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('End exam'), findsNothing);
      expect(find.byType(DashboardModuleCard), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  });
}
