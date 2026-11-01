// Choosing what the tracking radar follows: the in-screen picker (no
// target yet) and "Track another device" (switch while tracking).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/radar/view_model/tracking_radar_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import 'finder_fakes.dart';

final _now = DateTime.now();

ScannedDeviceModel _dev(
  String id,
  String name,
  int rssi, {
  String type = 'Smart Earpiece / Audio',
  DeviceTransport transport = DeviceTransport.ble,
}) => ScannedDeviceModel(
  id: id,
  name: name,
  deviceType: type,
  rssi: rssi,
  lastSeen: _now,
  firstSeen: _now,
  transport: transport,
);

final _earbud = _dev('AA:01', 'TWS Earbud', -58);
final _printer = _dev(
  'AA:02',
  'L3250 Series',
  -66,
  type: 'BLE Broadcast Beacon',
);
final _phone = _dev('AA:03', 'Galaxy S23', -80, type: 'Smartphone / Mobile');
final _speaker = _dev(
  'CC:01',
  'JBL Flip',
  -50,
  transport: DeviceTransport.classic,
);

class _Scanner extends FakeScanner {
  _Scanner({this.scanning = true});

  final bool scanning;

  @override
  ScannerState build() {
    final devices = [_phone, _printer, _earbud, _speaker];
    return ScannerState(
      isScanning: scanning,
      devices: devices,
      groups: [
        for (final d in devices) ScannedDeviceGroup([d]),
      ],
      trustedIds: const {'AA:02'},
      alerts: [
        NewDeviceAlert(
          deviceId: 'AA:01',
          displayName: 'TWS Earbud',
          deviceType: 'Smart Earpiece / Audio',
          transport: DeviceTransport.ble,
          rssi: -58,
          detectedAt: _now,
        ),
      ],
    );
  }
}

final _shotDir = Platform.environment['RADAR_SHOTS'];
final _boundary = GlobalKey();

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool scanning = true,
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const screen = TrackingRadarScreen();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(FakeFinderBluetooth()),
          wakelockServiceProvider.overrideWithValue(FakeWakelock()),
          hapticServiceProvider.overrideWithValue(FakeHaptics()),
          scannerViewModelProvider.overrideWith(
            () => _Scanner(scanning: scanning),
          ),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => RepaintBoundary(
              key: _boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: mode,
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
  for (
    var i = 0;
    i < 40 && find.byType(TrackingRadarScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
  return ProviderScope.containerOf(
    tester.element(find.byType(TrackingRadarScreen)),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    if (_shotDir != null) await loadFonts();
  });

  testWidgets('without a target the radar lists BLE devices, closest first', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Which device do you want to find?'), findsOneWidget);
    final rows = [
      for (final id in ['AA:01', 'AA:02', 'AA:03'])
        tester.getTopLeft(find.byKey(ValueKey('radar_pick_$id'))).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));
    // Classic Bluetooth can't be tracked live: not offered.
    expect(find.byKey(const ValueKey('radar_pick_CC:01')), findsNothing);
    // Badges.
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Trusted'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shot(tester, 'radar_pick_light');
  });

  testWidgets('tapping a device starts tracking it', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('radar_pick_AA:01')));
    await _frames(tester);
    expect(c.read(trackingRadarViewModelProvider).device?.id, 'AA:01');
    expect(find.text('Which device do you want to find?'), findsNothing);
    expect(find.byKey(const Key('radar_change_device')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shot(tester, 'radar_tracking');
  });

  testWidgets('"Track another device" switches the target in place', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('radar_pick_AA:01')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('radar_change_device')));
    await _frames(tester);
    expect(find.text('Tracking'), findsOneWidget, reason: 'current marked');
    await _shot(tester, 'radar_switch_sheet');
    final other = find.byKey(const ValueKey('radar_pick_AA:03'));
    // Scroll the sheet's list to it, as a user would.
    await tester.scrollUntilVisible(
      other,
      80,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pump();
    await tester.tap(other);
    await _frames(tester);
    expect(c.read(trackingRadarViewModelProvider).device?.id, 'AA:03');
  });

  testWidgets('"Not trusted" and search narrow the list', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('radar_pick_untrusted')));
    await tester.pump();
    expect(find.byKey(const ValueKey('radar_pick_AA:02')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('radar_pick_search')),
      'galaxy',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('radar_pick_AA:03')), findsOneWidget);
    expect(find.byKey(const ValueKey('radar_pick_AA:01')), findsNothing);
    await tester.enterText(find.byKey(const Key('radar_pick_search')), 'zzz');
    await tester.pump();
    expect(find.text('No device matches'), findsOneWidget);
  });

  testWidgets('scanner not running explains what to do', (tester) async {
    await _pump(tester, scanning: false);
    expect(find.text("The scanner isn't running"), findsOneWidget);
    expect(find.text('Open scanner'), findsOneWidget);
    await _shot(tester, 'radar_pick_not_scanning');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final locale in const [Locale('bn'), Locale('ar')]) {
      testWidgets('picker fits a small phone (${locale.languageCode}, $mode)', (
        tester,
      ) async {
        await _pump(tester, mode: mode, locale: locale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
