// Approximate distance shown to invigilators instead of raw dBm.

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/features/scanner/model/distance_estimate.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/distance_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DistanceEstimate', () {
    test('calibrated RSSI at 1 m is 1 m, weaker is farther', () {
      expect(DistanceEstimate.meters(-59), closeTo(1, 0.001));
      expect(DistanceEstimate.meters(-65), greaterThan(1));
      expect(
        DistanceEstimate.meters(-80),
        greaterThan(DistanceEstimate.meters(-70)),
      );
    });

    test('uses advertised TX power, ignores implausible values', () {
      expect(DistanceEstimate.rssiAt1m(4), -37);
      expect(DistanceEstimate.rssiAt1m(99), DistanceEstimate.defaultRssiAt1m);
      expect(DistanceEstimate.forDevice(-37, 4), closeTo(1, 0.001));
    });
  });

  group('distance text', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    Future<void> pumpEn(WidgetTester tester) async {
      rootBundle.clear();
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          startLocale: const Locale('en'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const SizedBox(key: Key('ready')),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.byKey(const Key('ready')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('whole metres, clamped below 1 m and above 10 m', (
      tester,
    ) async {
      await pumpEn(tester);
      expect(approxDistanceText(-50), '<1 m');
      expect(approxDistanceText(-59), '≈1 m');
      expect(approxDistanceText(-71), '≈3 m');
      expect(approxDistanceText(-95), '>10 m');
    });

    testWidgets('BLE reads as distance, Wi-Fi / classic keep dBm', (
      tester,
    ) async {
      await pumpEn(tester);
      expect(
        signalSummaryText(-71, DeviceTransport.ble),
        '≈3 m away',
      );
      expect(signalSummaryText(-71, DeviceTransport.wifi), '-71 dBm');
      expect(signalSummaryText(-71, DeviceTransport.classic), '-71 dBm');
    });
  });
}
