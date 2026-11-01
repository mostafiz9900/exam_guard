// Sheets never trap the user: every sheet goes through showAppBottomSheet
// (safe area, at most 90% high, drag handle), and the device details sheet
// can always be closed — even with a long activity history on a small phone.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/presence_tracker.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/widgets/device_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('no showModalBottomSheet outside the shared helper', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('app_bottom_sheet.dart') &&
            f.readAsStringSync().contains('showModalBottomSheet('))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  group('device details sheet', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    final now = DateTime.now();
    final device = ScannedDeviceModel(
      id: 'AA:BB:CC:DD:EE:01',
      name: 'TWS Earbud',
      deviceType: 'Smart Earpiece / Audio',
      rssi: -58,
      serviceUuids: const ['180F', '180A', 'FE2C'],
      lastSeen: now,
      firstSeen: now,
    );
    final history = DeviceHistory(
      intervals: [
        PresenceInterval(now.subtract(const Duration(minutes: 9)), now),
      ],
      samples: [
        for (var s = 540; s >= 0; s -= 5)
          SignalSample(now.subtract(Duration(seconds: s)), -60),
      ],
      reappearances: [
        for (var i = 1; i <= 4; i++) now.subtract(Duration(minutes: i * 2)),
      ],
      peakRssi: -52,
    );

    Future<void> open(WidgetTester tester) async {
      rootBundle.clear();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          startLocale: const Locale('en'),
          saveLocale: false,
          child: Builder(
            builder: (context) => AppScreenSize(
              builder: (_) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Scaffold(
                  appBar: AppBar(title: const Text('SCANNER')),
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDeviceDetailsSheet(
                        context,
                        device,
                        history: history,
                        isTrusted: false,
                        onConnect: () {},
                        onToggleTrust: () {},
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40 && find.text('open').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('stays below the top bar and closes with ✕', (tester) async {
      await open(tester);
      final close = find.byKey(const Key('device_details_close'));
      expect(close, findsOneWidget);
      // The sheet (and its ✕) start below the app bar: the page behind
      // stays visible.
      expect(tester.getTopLeft(close).dy, greaterThan(56));
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(close, findsNothing);
    });

    testWidgets('tapping the page behind closes it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(160, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device_details_close')), findsNothing);
    });
  });
}
