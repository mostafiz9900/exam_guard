// Baseline card and new-device alerts on a small phone: honest disabled
// state, compact line after the baseline, red banner and alerts sheet.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/widgets/new_device_alert_banner.dart';
import 'package:exam_guard/features/dashboard/view/widgets/room_baseline_card.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scanner with a fixed state and no hardware.
class _FakeScanner extends ScannerViewModel {
  _FakeScanner(this.initial);

  final ScannerState initial;
  final acknowledged = <String>[];
  var acknowledgedAll = false;

  @override
  ScannerState build() => initial;

  @override
  void acknowledgeAlert(String deviceId) => acknowledged.add(deviceId);

  @override
  void acknowledgeAll() => acknowledgedAll = true;
}

final _t = DateTime(2026, 10, 18, 9, 30);

NewDeviceAlert _alert(String id, String name, DeviceTransport transport) =>
    NewDeviceAlert(
      deviceId: id,
      displayName: name,
      deviceType: 'Smart Earpiece / Audio',
      transport: transport,
      rssi: -61,
      detectedAt: _t,
    );

Future<_FakeScanner> _pump(
  WidgetTester tester,
  ScannerState state,
  Widget child,
) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeScanner(state);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [scannerViewModelProvider.overrideWith(() => fake)],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp(
              theme: AppTheme.darkTheme,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [child]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 40 && find.byType(Scaffold).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
  return fake;
}

/// Real Roboto metrics instead of the wide test font, like the responsive
/// test.
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('baseline button is disabled while Location is off', (
    tester,
  ) async {
    await _pump(
      tester,
      ScannerState(isScanning: true, isLocationOff: true),
      const RoomBaselineCard(),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseline button is enabled while scanning live', (tester) async {
    await _pump(
      tester,
      ScannerState(isScanning: true),
      const RoomBaselineCard(),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('after the baseline only a compact line is shown', (
    tester,
  ) async {
    await _pump(
      tester,
      ScannerState(isScanning: true, baselineAt: _t, trustedIds: {'a', 'b'}),
      const RoomBaselineCard(),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner hidden without unacknowledged alerts', (tester) async {
    await _pump(tester, ScannerState(), const NewDeviceAlertBanner());
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('banner opens the alerts sheet with its actions', (tester) async {
    final fake = await _pump(
      tester,
      ScannerState(
        isScanning: true,
        baselineAt: _t,
        alerts: [
          _alert('b1', 'Galaxy Buds2 Pro', DeviceTransport.ble),
          _alert('wifi:aa', 'AndroidAP-1234', DeviceTransport.wifi),
        ],
        alertSeq: 2,
      ),
      const NewDeviceAlertBanner(),
    );
    expect(find.byIcon(Icons.notification_important_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Galaxy Buds2 Pro'), findsWidgets);
    expect(find.text('AndroidAP-1234'), findsWidgets);
    // BLE device that is no longer heard can't be tracked.
    expect(find.text('Track'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.done_all_rounded));
    expect(fake.acknowledgedAll, isTrue);
  });
}
