// Magnetic scanner screen: renders on a small phone (light/dark), never shows
// "normal" while not measuring, maps the change from baseline to the hazard
// level/colour per sensitivity preset, calibrates, shows the guide, mutes the
// buzzer under the incident form and stops the sensor when closed.
//
// The magnetometer and the shared buzzer are faked; no real sensor is used.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view/magnetic_scanner_screen.dart';
import 'package:exam_guard/features/magnetic/view/widgets/guide_step_item.dart';
import 'package:exam_guard/features/magnetic/view/widgets/magnetic_gauge_painter.dart';
import 'package:exam_guard/features/magnetic/view/widgets/stat_item.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _alertRed = Color(0xFFDC2626);

class _FakeMagnetometer implements IMagnetometerService {
  _FakeMagnetometer() {
    controller = StreamController<MagnetometerReading>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
  }

  late final StreamController<MagnetometerReading> controller;
  var listens = 0;
  var cancels = 0;

  bool get hasListener => controller.hasListener;

  void emit(double magnitude) => controller.add(
    MagnetometerReading(x: magnitude, y: 0, z: 0, timestamp: DateTime.now()),
  );

  @override
  Stream<MagnetometerReading> readings() => controller.stream;
}

/// Records what the view model asks of the shared buzzer; never beeps.
class _FakeBuzzer implements GeigerBuzzerService {
  final distances = <double>[];
  var stops = 0;

  @override
  bool get isEnabled => true;

  @override
  bool get isAlertPlaying => false;

  @override
  void toggleAudio(bool enabled) {}

  @override
  void updateTargetDistance(double distanceMeters) =>
      distances.add(distanceMeters);

  @override
  void stopBuzzer() => stops++;

  @override
  void playAlert({
    int clicks = 4,
    Duration gap = const Duration(milliseconds: 110),
  }) {}

  @override
  void stopAlert() {}
}

class _Harness {
  _Harness(this.sensor, this.buzzer, this.router);
  final _FakeMagnetometer sensor;
  final _FakeBuzzer buzzer;
  final GoRouter router;
  ActionEntryArgs? pushedArgs;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
}) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final sensor = _FakeMagnetometer();
  final buzzer = _FakeBuzzer();
  late _Harness harness;
  final router = GoRouter(
    initialLocation: AppRoute.magnetic,
    routes: [
      GoRoute(
        path: AppRoute.dashboard,
        builder: (_, _) => const Scaffold(body: Text('DASHBOARD_STUB')),
      ),
      GoRoute(
        path: AppRoute.magnetic,
        builder: (_, _) => const MagneticScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.scanner,
        builder: (_, _) => const Scaffold(body: Text('SCANNER_STUB')),
      ),
      GoRoute(
        path: AppRoute.actionNew,
        builder: (_, state) {
          harness.pushedArgs = state.extra as ActionEntryArgs?;
          return const Scaffold(body: Text('ACTION_STUB'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  harness = _Harness(sensor, buzzer, router);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          magnetometerServiceProvider.overrideWithValue(sensor),
          geigerBuzzerProvider.overrideWithValue(buzzer),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp.router(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(MagneticScannerScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let the view model's startScanning microtask subscribe.
  await tester.pump();
  await tester.pump();
  return harness;
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MagneticScannerScreen)),
);

MagneticState _state(WidgetTester tester) =>
    _container(tester).read(magneticViewModelProvider);

/// Emits one reading and lets the 100 ms UI throttle publish it.
Future<void> _emit(WidgetTester tester, _Harness h, double magnitude) async {
  h.sensor.emit(magnitude);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

MagneticGaugePainter _gauge(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .whereType<MagneticGaugePainter>()
    .single;

String _statValue(WidgetTester tester, String label) => tester
    .widgetList<StatItem>(find.byType(StatItem))
    .firstWhere((s) => s.label == label)
    .value;

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Real Roboto metrics: the default test font draws every glyph 1 em wide,
/// which overflows rows that fit on a real phone.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String file) async =>
      ByteData.view(File('$dir/$file').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Light', 'Black']) {
    roboto.addFont(bytes('Roboto-$f.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(bytes('MaterialIcons-Regular.otf'))).load();
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
    await _loadFonts();
  });

  group('MagneticHazardLevel / MagneticSensitivity', () {
    test('labels and translation keys', () {
      expect(MagneticHazardLevel.normal.labelKey, 'mag_level_normal');
      expect(
        MagneticHazardLevel.strongSource.labelKey,
        'mag_level_strong_source',
      );
      expect(
        MagneticHazardLevel.strongSource.suggestionKey,
        'mag_level_strong_source_hint',
      );
      expect(
        MagneticHazardLevel.elevated.suggestionKey,
        'mag_level_elevated_hint',
      );
      for (final level in MagneticHazardLevel.values) {
        expect(level.label, isNotEmpty);
      }
      expect(MagneticHazardLevel.critical.label, 'STRONG MAGNETIC ANOMALY');
    });

    test('presets are T = 35 / 20 / 10 μT', () {
      expect(MagneticSensitivity.low.threshold, 35);
      expect(MagneticSensitivity.medium.threshold, 20);
      expect(MagneticSensitivity.high.threshold, 10);
      expect(MagneticSensitivity.high.labelKey, 'mag_sensitivity_high');
      expect(
        MagneticSensitivity.medium.chipLabel,
        'Medium sensitivity (±20 μT)',
      );
    });

    test('gauge painter repaints only on change', () {
      MagneticGaugePainter p(double m) => MagneticGaugePainter(
        magnitude: m,
        angle: 0,
        color: _green,
        trackColor: Colors.grey,
      );
      expect(p(10).shouldRepaint(p(10)), isFalse);
      expect(p(10).shouldRepaint(p(20)), isTrue);
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders without overflow on a small phone ($mode)', (
      tester,
    ) async {
      final h = await _pump(tester, mode: mode);
      expect(find.text('Magnetic scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Live and strong: the longest labels.
      await _emit(tester, h, 45);
      await _emit(tester, h, 300);
      expect(
        find.text('VERY STRONG SOURCE — DEVICE AT CONTACT RANGE'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Scroll to the bottom: nothing overflows below the fold either.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(find.text('Log incident'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }

  testWidgets('waiting for the first reading is not "normal"', (tester) async {
    await _pump(tester);
    expect(find.text('WAITING FOR SENSOR…'), findsWidgets);
    expect(find.text('NORMAL AMBIENT FIELD'), findsNothing);
    // Calibration needs a live reading.
    final calibrate = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Calibrate baseline'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(calibrate.onPressed, isNull);
    expect(_gauge(tester).color, isNot(_green));
    await _unmount(tester);
  });

  testWidgets('no magnetometer: explains, never shows "normal"', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();

    expect(_state(tester).isSensorUnavailable, isTrue);
    expect(find.text('SENSOR UNAVAILABLE'), findsOneWidget);
    expect(find.text('No magnetometer on this phone'), findsOneWidget);
    expect(find.text('NORMAL AMBIENT FIELD'), findsNothing);
    expect(find.byType(MagneticGaugePainter), findsNothing);
    expect(find.text('Log incident'), findsNothing);
    expect(tester.takeException(), isNull);

    // Still listening: a slow sensor comes live by itself.
    expect(h.sensor.hasListener, isTrue);
    await _emit(tester, h, 45);
    expect(find.text('MAGNETOMETER LIVE'), findsOneWidget);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('no magnetometer: "open scanner" pushes the scanner', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER_STUB'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('sensor error offers Retry, which restarts the sensor', (
    tester,
  ) async {
      final h = await _pump(tester);
      h.sensor.controller.addError(Exception('NO_SENSOR'));
      await tester.pump();
      await tester.pump();
      expect(_state(tester).isSensorUnavailable, isTrue);
      expect(find.text('NORMAL AMBIENT FIELD'), findsNothing);
      // The subscription was cancelled on error; the user needs a way back.
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await _emit(tester, h, 45);
      expect(_state(tester).isLive, isTrue);
      await _unmount(tester);
  });

  testWidgets('paused: not-measuring banner with Resume, never "normal"', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause sensor'));
    await tester.pump();
    expect(find.text('NOT MEASURING — sensor paused'), findsOneWidget);
    expect(find.text('SENSOR PAUSED'), findsOneWidget);
    expect(find.text('NORMAL AMBIENT FIELD'), findsNothing);
    expect(_gauge(tester).color, isNot(_green));
    expect(h.sensor.hasListener, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Resume sensor'));
    await tester.pump();
    await tester.pump();
    expect(h.sensor.hasListener, isTrue);
    expect(find.text('WAITING FOR SENSOR…'), findsWidgets);
    await _emit(tester, h, 46);
    expect(find.text('MAGNETOMETER LIVE'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('baseline → elevated → critical → strong (medium, T = 20 μT)', (
    tester,
  ) async {
    final h = await _pump(tester);

    // First reading is the automatic baseline.
    await _emit(tester, h, 45);
    expect(_state(tester).baseline, 45);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);
    expect(_textColor(tester, 'NORMAL AMBIENT FIELD'), _green);
    expect(find.text('45.0'), findsOneWidget);
    expect(_statValue(tester, 'Baseline (auto)'), '45.0 μT');
    expect(_gauge(tester).color, _green);

    // Δ 19 ≤ T: still normal (change from baseline only).
    await _emit(tester, h, 64);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);

    // Δ 25 > T.
    await _emit(tester, h, 70);
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);
    expect(_textColor(tester, 'METAL / ANOMALY DETECTED'), _amber);
    expect(find.text('70.0'), findsOneWidget);
    expect(_gauge(tester).color, _amber);
    expect(_gauge(tester).magnitude, 70);

    // Δ 45 > 2T.
    await _emit(tester, h, 90);
    expect(find.text('STRONG MAGNETIC ANOMALY'), findsOneWidget);
    expect(_textColor(tester, 'STRONG MAGNETIC ANOMALY'), _red);
    expect(_gauge(tester).color, _red);

    // Δ 85 > 4T.
    await _emit(tester, h, 130);
    const strong = 'VERY STRONG SOURCE — DEVICE AT CONTACT RANGE';
    expect(find.text(strong), findsOneWidget);
    expect(_textColor(tester, strong), _alertRed);
    expect(_gauge(tester).color, _alertRed);
    expect(_statValue(tester, 'Peak hold'), '130.0 μT');

    // A drop below baseline counts too: Δ 25.
    await _emit(tester, h, 20);
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);
    // Peak hold keeps the maximum.
    expect(_statValue(tester, 'Peak hold'), '130.0 μT');

    // The buzzer beeps faster as the level rises, only while live.
    expect(h.buzzer.distances, containsAllInOrder([4.0, 2.0, 0.5, 4.0]));
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('sensitivity presets re-evaluate the current change', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    await _emit(tester, h, 70); // Δ 25

    expect(find.text('Medium sensitivity (±20 μT)'), findsOneWidget);
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);

    await _tapVisible(tester, find.text('Low sensitivity (±35 μT)'));
    expect(_state(tester).sensitivity, MagneticSensitivity.low);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Low sensitivity (±35 μT)'),
          )
          .selected,
      isTrue,
    );

    await _tapVisible(tester, find.text('High sensitivity (±10 μT)'));
    expect(_state(tester).sensitivity, MagneticSensitivity.high);
    expect(find.text('STRONG MAGNETIC ANOMALY'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Low sensitivity (±35 μT)'),
          )
          .selected,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('calibrate sets the baseline to the live field', (tester) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    await _emit(tester, h, 70);
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);
    expect(
      find.textContaining('Baseline is the first reading'),
      findsOneWidget,
    );

    await _tapVisible(tester, find.text('Calibrate baseline'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Baseline set to 70.0 μT'), findsOneWidget);
    final s = _state(tester);
    expect(s.baseline, 70);
    expect(s.isBaselineCalibrated, isTrue);
    expect(s.peakValue, 70);
    expect(s.peakHazard, MagneticHazardLevel.normal);
    expect(find.text('NORMAL AMBIENT FIELD'), findsOneWidget);
    expect(_statValue(tester, 'Baseline'), '70.0 μT');
    expect(find.textContaining('Baseline is the first reading'), findsNothing);

    // Later readings are measured against the new baseline.
    await _emit(tester, h, 95); // Δ 25
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);
    await _emit(tester, h, 45); // Δ 25 below
    expect(find.text('METAL / ANOMALY DETECTED'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('guide opens from the chip and the app bar and closes', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(InkWell, 'How to use'));
    await tester.pumpAndSettle();
    expect(find.text('Magnetic scanner guide'), findsOneWidget);
    expect(find.byType(GuideStepItem), findsWidgets);
    expect(find.text('How to scan'), findsOneWidget);
    expect(find.textContaining('±35 / 20 / 10 μT'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Got it, start scanning'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Logging an incident'), findsOneWidget);
    await tester.tap(find.text('Got it, start scanning'));
    await tester.pumpAndSettle();
    expect(find.text('Magnetic scanner guide'), findsNothing);

    await tester.tap(find.byTooltip('How to use'));
    await tester.pumpAndSettle();
    expect(find.text('Magnetic scanner guide'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('audio toggle silences the buzzer', (tester) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    await _emit(tester, h, 90);
    expect(h.buzzer.distances.last, 2.0);

    await tester.tap(find.byTooltip('Audio alert on/off'));
    await tester.pump();
    expect(_state(tester).isBuzzerEnabled, isFalse);
    expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    final count = h.buzzer.distances.length;
    final stops = h.buzzer.stops;
    await _emit(tester, h, 130);
    expect(h.buzzer.distances.length, count);
    expect(h.buzzer.stops, greaterThan(stops));
    await _unmount(tester);
  });

  testWidgets('log incident pushes the form and mutes alerts until back', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    await _emit(tester, h, 70);
    expect(h.buzzer.distances.last, 4.0);

    final stopsBefore = h.buzzer.stops;
    await _tapVisible(tester, find.text('Log incident'));
    await tester.pumpAndSettle();
    expect(find.text('ACTION_STUB'), findsOneWidget);
    expect(h.pushedArgs?.category, 'Magnetic Anomaly');
    expect(h.pushedArgs?.notes, contains('peak 70.0 μT'));
    expect(h.pushedArgs?.notes, contains('baseline 45.0 μT auto'));
    expect(h.buzzer.stops, greaterThan(stopsBefore));

    // Readings under the form do not beep.
    final count = h.buzzer.distances.length;
    await _emit(tester, h, 130);
    await _emit(tester, h, 90);
    expect(h.buzzer.distances.length, count);

    // Back on the magnetic screen: alerts resume.
    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MagneticScannerScreen), findsOneWidget);
    expect(h.buzzer.distances.length, greaterThan(count));
    expect(h.buzzer.distances.last, 2.0);
    await _unmount(tester);
  });

  testWidgets('back with nothing to pop goes to the dashboard', (
    tester,
  ) async {
    await _pump(tester);
    final popScope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(MagneticScannerScreen),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      ),
    );
    expect(popScope.canPop, isFalse);
    popScope.onPopInvokedWithResult?.call(false, null);
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD_STUB'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('closing the screen cancels the sensor and stops the buzzer', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _emit(tester, h, 45);
    await _emit(tester, h, 90);
    expect(h.sensor.listens, 1);
    expect(h.sensor.hasListener, isTrue);
    final stops = h.buzzer.stops;

    await _unmount(tester);
    expect(h.sensor.hasListener, isFalse);
    expect(h.sensor.cancels, 1);
    expect(h.buzzer.stops, greaterThan(stops));
    // Nothing reacts to late samples.
    h.sensor.emit(200);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
