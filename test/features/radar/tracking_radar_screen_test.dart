// Tracking radar screen: renders every state (acquiring, live, signal lost,
// Location off, non-BLE) at phone sizes in light/dark and LTR/RTL without
// overflow, and checks the main interactions.
//
// Set SCREENSHOTS=1 to also write PNGs to build/screenshots/radar_*.png.
// Optional: RADAR_I18N_EXTRA=<dir with radar.<lang>.json> merges not-yet-
// merged keys; FONTS_DIR=<dir with NotoSansBengali/Arabic> renders bn/ar.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/radar/view/widgets/finder_issue_banner.dart';
import 'package:exam_guard/features/radar/view_model/tracking_radar_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

import 'finder_fakes.dart';

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final lang = locale.languageCode;
    final map = jsonDecode(
      File('assets/translations/$lang.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final extra = Platform.environment['RADAR_I18N_EXTRA'];
    if (extra != null) {
      final file = File('$extra/radar.$lang.json');
      if (file.existsSync()) {
        map.addAll(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
      }
    }
    return map;
  }
}

const _fallbackFonts = ['NotoBengali', 'NotoArabic'];

Future<void> _loadFonts() async {
  ByteData bytes(String path) =>
      ByteData.view(File(path).readAsBytesSync().buffer);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = '$root/bin/cache/artifacts/material_fonts';
    final roboto = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      roboto.addFont(Future.value(bytes('$dir/Roboto-$f.ttf')));
    }
    await roboto.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(bytes('$dir/MaterialIcons-Regular.otf')))).load();
  }
  final fonts = Platform.environment['FONTS_DIR'];
  if (fonts != null) {
    final bn = FontLoader('NotoBengali')
      ..addFont(Future.value(bytes('$fonts/NotoSansBengali-Regular.ttf')))
      ..addFont(Future.value(bytes('$fonts/NotoSansBengali-Bold.ttf')));
    await bn.load();
    await (FontLoader('NotoArabic')
          ..addFont(Future.value(bytes('$fonts/NotoSansArabic-Regular.ttf'))))
        .load();
  }
}

ThemeData _withFallback(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamilyFallback: _fallbackFonts),
);

var _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  if (Platform.environment['SCREENSHOTS'] != '1') return;
  final element = find.byKey(_boundary).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/radar_$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

ScannedDeviceModel _target({DeviceTransport transport = DeviceTransport.ble}) =>
    ScannedDeviceModel(
      id: 'B4:12:7A:9C:00:11',
      name: 'Samsung Galaxy Buds2 Pro Wireless Earbuds',
      rssi: -70,
      lastSeen: DateTime.now(),
      firstSeen: DateTime.now(),
      transport: transport,
    );

/// Radar frozen in one state (the signal-lost timer uses the wall clock,
/// so the screen test does not wait 5 s of real time for it).
class _FixedRadar extends TrackingRadarViewModel {
  _FixedRadar(this.fixed);

  final TrackingRadarState fixed;

  @override
  TrackingRadarState build() => fixed;

  @override
  Future<void> setTargetDevice(ScannedDeviceModel device) async {}

  @override
  void setAlertsSuspended(bool suspended) {}
}

TrackingRadarState _lostState() => TrackingRadarState(
  device: _target().copyWith(
    lastSeen: DateTime.now().subtract(const Duration(seconds: 7)),
  ),
  distanceMeters: 2.1,
  rssi: -63,
  smoothedRssi: -62,
  peakCloseness: 72,
  peakRssi: -59,
  isSignalLost: true,
);

class _TrustingScanner extends FakeScanner {
  @override
  ScannerState build() => ScannerState(trustedIds: const {'B4:12:7A:9C:00:11'});
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required Locale locale,
  required FakeFinderBluetooth bluetooth,
  ScannedDeviceModel? device,
  bool trusted = false,
  TrackingRadarState? fixedRadar,
}) async {
  _boundary = GlobalKey();
  rootBundle.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final screen = TrackingRadarScreen(targetDevice: device ?? _target());
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: locale,
        saveLocale: false,
        assetLoader: const _Loader(),
        child: ProviderScope(
          overrides: [
            bluetoothServiceProvider.overrideWithValue(bluetooth),
            wakelockServiceProvider.overrideWithValue(FakeWakelock()),
            hapticServiceProvider.overrideWithValue(FakeHaptics()),
            scannerViewModelProvider.overrideWith(
              trusted ? _TrustingScanner.new : FakeScanner.new,
            ),
            if (fixedRadar != null)
              trackingRadarViewModelProvider.overrideWith(
                () => _FixedRadar(fixedRadar),
              ),
          ],
          child: Builder(
            builder: (context) => AppScreenSize(
              builder: (_) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _withFallback(AppTheme.lightTheme),
                darkTheme: _withFallback(AppTheme.darkTheme),
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: screen,
              ),
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

/// Packets over the last 3 s: rising to -55 dBm ("warmer"), or rising
/// then falling back ("colder", peak marker ahead of the value).
void _feedLive(ProviderContainer container, {bool colder = false}) {
  final vm = container.read(trackingRadarViewModelProvider.notifier);
  final start = DateTime.now().subtract(const Duration(seconds: 3));
  for (var i = 0; i <= 30; i++) {
    final rssi = colder
        ? (i < 15 ? -80 + i * 2 : -52 - (i - 15))
        : -82 + (i * 0.9).round();
    vm.updateDeviceSignal(rssi, start.add(Duration(milliseconds: 100 * i)));
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

enum _State { acquiring, live, colder, lost, locationOff, wifi }

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  const sizes = {'360x800': Size(360, 800), '320x640': Size(320, 640)};
  const locales = [Locale('en'), Locale('ar')];

  Future<void> drive(
    WidgetTester tester,
    _State state,
    ProviderContainer container,
    FakeFinderBluetooth bluetooth,
  ) async {
    switch (state) {
      case _State.acquiring:
      case _State.wifi:
        break;
      case _State.live:
        _feedLive(container);
      case _State.colder:
        _feedLive(container, colder: true);
      case _State.lost:
        break;
      case _State.locationOff:
        bluetooth.problems.add(BleScanError.locationOff);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
    }
    await _frames(tester);
  }

  for (final state in _State.values) {
    for (final size in sizes.entries) {
      for (final brightness in Brightness.values) {
        for (final locale in locales) {
          final name =
              '${state.name}_${size.key}_${brightness.name}_'
              '${locale.languageCode}';
          testWidgets('radar $name renders without overflow', (tester) async {
            final bluetooth = FakeFinderBluetooth();
            final container = await _pump(
              tester,
              size: size.value,
              brightness: brightness,
              locale: locale,
              bluetooth: bluetooth,
              device: state == _State.wifi
                  ? _target(transport: DeviceTransport.wifi)
                  : null,
              trusted: state == _State.live,
              fixedRadar: state == _State.lost ? _lostState() : null,
            );
            await drive(tester, state, container, bluetooth);
            final radar = container.read(trackingRadarViewModelProvider);

            expect(find.byKey(const Key('radar_hero')), findsOneWidget);
            expect(
              find.byKey(const Key('radar_target_header')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('radar_log_incident')), findsOneWidget);
            switch (state) {
              case _State.live:
              case _State.colder:
                expect(radar.hasLiveSignal, isTrue);
                expect(find.byKey(const Key('radar_percent')), findsOneWidget);
                expect(find.byKey(const Key('radar_pill')), findsOneWidget);
                expect(radar.peakCloseness, isNotNull);
                if (state == _State.colder) {
                  expect(radar.trend.isCloser, isFalse);
                } else {
                  expect(
                    find.byKey(const Key('radar_trusted_badge')),
                    findsOneWidget,
                  );
                }
              case _State.acquiring:
              case _State.wifi:
                expect(radar.isAcquiring, isTrue);
                expect(find.byKey(const Key('radar_percent')), findsNothing);
              case _State.lost:
                expect(radar.isSignalLost, isTrue);
                expect(find.byKey(const Key('radar_pill')), findsOneWidget);
              case _State.locationOff:
                expect(radar.isLocationOff, isTrue);
                final banner = tester.widget<FinderIssueBanner>(
                  find.byType(FinderIssueBanner),
                );
                expect(banner.issue, FinderScanIssue.locationOff);
            }
            expect(
              find.byKey(const Key('radar_find_seat')),
              state == _State.wifi ? findsNothing : findsOneWidget,
            );
            // The gauge is above the fold.
            final hero = tester.getRect(find.byKey(const Key('radar_hero')));
            expect(hero.top, lessThan(size.value.height / 2));

            await _shot(tester, name);
            expect(tester.takeException(), isNull);
            await _unmount(tester);
          });
        }
      }
    }
  }

  testWidgets('radar in Bangla and at 600 dp wide renders', (tester) async {
    for (final (size, locale) in const [
      (Size(360, 800), Locale('bn')),
      (Size(600, 960), Locale('en')),
      (Size(800, 360), Locale('en')),
    ]) {
      final bluetooth = FakeFinderBluetooth();
      final container = await _pump(
        tester,
        size: size,
        brightness: Brightness.light,
        locale: locale,
        bluetooth: bluetooth,
      );
      _feedLive(container);
      await _frames(tester);
      await _shot(
        tester,
        'live_${size.width.toInt()}x${size.height.toInt()}_light_'
        '${locale.languageCode}',
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    }
  });

  testWidgets('toggles, peak reset and guide work', (tester) async {
    final bluetooth = FakeFinderBluetooth();
    final container = await _pump(
      tester,
      size: const Size(360, 800),
      brightness: Brightness.dark,
      locale: const Locale('en'),
      bluetooth: bluetooth,
    );
    _feedLive(container);
    await _frames(tester);
    TrackingRadarState read() => container.read(trackingRadarViewModelProvider);

    expect(read().isVibrationEnabled, isTrue);
    await tester.tap(find.byKey(const Key('radar_toggle_vibration')));
    await tester.pump();
    expect(read().isVibrationEnabled, isFalse);

    expect(read().isAudioAlertEnabled, isTrue);
    await tester.tap(find.byKey(const Key('radar_toggle_audio')));
    await tester.pump();
    expect(read().isAudioAlertEnabled, isFalse);

    expect(read().peakCloseness, isNotNull);
    await tester.tap(find.byKey(const Key('radar_reset_peak')));
    await tester.pump();
    expect(read().peakCloseness, isNull);

    await tester.ensureVisible(find.byKey(const Key('radar_how_to_find')));
    await tester.tap(find.text('radar_how_to_find'.tr()));
    await _frames(tester);
    expect(find.text('radar_guide_step1_title'.tr()), findsOneWidget);
    await _shot(tester, 'guide_open_360x800_dark_en');

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('radar_target_name')));
    await _frames(tester);
    await tester.longPress(find.byKey(const Key('radar_target_name')));
    await _frames(tester);
    expect(copied, 'B4:12:7A:9C:00:11');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('reduced motion renders without the pulse', (tester) async {
    final bluetooth = FakeFinderBluetooth();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = await _pump(
      tester,
      size: const Size(360, 800),
      brightness: Brightness.light,
      locale: const Locale('en'),
      bluetooth: bluetooth,
    );
    _feedLive(container);
    await tester.pump();
    expect(find.byKey(const Key('radar_percent')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
