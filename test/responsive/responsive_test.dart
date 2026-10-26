// Renders every screen at several screen sizes, text scales and locales and
// fails on layout overflow or any other framework error.
//
//   fvm flutter test test/responsive
//
// Set SCREENSHOTS=1 to also write PNGs to build/screenshots/.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/app/app_router.dart';
import 'package:exam_guard/app/exam_guard_app.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenSize {
  const ScreenSize(this.name, this.width, this.height, {this.textScale = 1});

  final String name;
  final double width;
  final double height;
  final double textScale;
}

const sizes = [
  ScreenSize('small_phone_320x568', 320, 568),
  ScreenSize('phone_360x800', 360, 800),
  ScreenSize('phone_360x800_text1.3', 360, 800, textScale: 1.3),
  ScreenSize('large_phone_430x932', 430, 932),
  ScreenSize('phone_landscape_800x360', 800, 360),
  ScreenSize('tablet_800x1280', 800, 1280),
  ScreenSize('tablet_landscape_1280x800', 1280, 800),
];

final now = DateTime(2026, 10, 13, 10, 30);

ScannedDeviceModel device(String id, String name, int rssi, String type) =>
    ScannedDeviceModel(
      id: id,
      name: name,
      manufacturer: 'Samsung Electronics',
      deviceType: type,
      rssi: rssi,
      txPower: -12,
      isConnectable: true,
      serviceUuids: const ['180F', 'FE9F'],
      lastSeen: now,
      firstSeen: now,
    );

final targetDevice = device(
  'B4:12:7A:9C:00:11',
  'Samsung Galaxy Buds2 Pro Wireless Earbuds',
  -58,
  'Smart Earpiece / Audio',
);

class Screen {
  const Screen(this.name, this.route, {this.extra, this.withSession = true});

  final String name;
  final String route;
  final Object? extra;

  /// Whether storage holds a running exam.
  final bool withSession;
}

final screens = [
  const Screen('session_setup', AppRoute.sessionSetup, withSession: false),
  const Screen('dashboard', AppRoute.dashboard),
  const Screen('wireless_scanner', AppRoute.scanner),
  Screen('tracking_radar', AppRoute.radar, extra: targetDevice),
  const Screen('magnetic_scanner', AppRoute.magnetic),
  const Screen('rf_detector', AppRoute.rfDetector),
  Screen('action_entry', AppRoute.actionNew, extra: targetDevice),
  const Screen('report_summary', AppRoute.report),
];

// ---------------------------------------------------------------- fakes

class FakeBluetooth implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final _records = StreamController<BleScanRecord>.broadcast();

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => _records.stream;

  final problems = StreamController<BleScanError?>.broadcast();

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {
    scheduleMicrotask(() {
      final ts = DateTime.now();
      for (final (id, name, rssi) in [
        ('B4:12:7A:9C:00:11', 'Samsung Galaxy Buds2 Pro Wireless Earbuds', -58),
        ('F0:99:B6:21:7C:44', 'iPhone', -66),
        ('24:DC:C3:A1:B2:C3', 'ExamGuard-RF-Node', -49),
        ('7C:2E:0D:11:22:33', '', -81),
        ('11:22:33:44:55:66', 'Mi Smart Band 8 Active', -92),
      ]) {
        if (_records.isClosed) return;
        _records.add(
          BleScanRecord(
            id: id,
            name: name,
            rssi: rssi,
            txPower: -12,
            isConnectable: true,
            serviceUuids: const ['180F'],
            manufacturerData: const {
              76: [1, 2],
            },
            timestamp: ts,
          ),
        );
      }
    });
  }

  @override
  Future<void> stopScan(String owner) async {}

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      const BleConnectionInfo(batteryLevel: 64, gattName: 'Galaxy Buds2 Pro');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async => _records.close();
}

class GrantedPermissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakeMagnetometer implements IMagnetometerService {
  @override
  Stream<MagnetometerReading> readings() => Stream.fromIterable([
    for (var i = 0; i < 20; i++)
      MagnetometerReading(
        x: 22 + i.toDouble(),
        y: -18,
        z: 39 + i * 3,
        timestamp: now,
      ),
  ]);
}

class MemoryStorage implements ILocalStorage {
  MemoryStorage({bool withSession = true}) {
    if (!withSession) return;
    final session = SessionModel(
      id: '1',
      instituteName: 'Dhaka Residential Model College — Main Examination Hall',
      teacherName: 'Md. Abdur Rahman Chowdhury',
      roomNumber: '302-B',
      startTime: now.subtract(const Duration(hours: 1, minutes: 12)),
      deviceLogs: [
        for (final (sev, name) in [
          (LogSeverity.critical, 'Samsung Galaxy Buds2 Pro Wireless Earbuds'),
          (LogSeverity.high, 'iPhone 15 Pro Max'),
          (LogSeverity.low, 'Calculator with Bluetooth'),
        ])
          ActionLogModel(
            deviceName: name,
            deviceId: 'B4:12:7A:9C:00:11',
            category: 'Bluetooth Device',
            severity: sev,
            location: 'Row 4, Desk 17 (near the window)',
            notes:
                'Found inside the left jacket pocket during the second sweep.',
            createdAt: now,
          ),
      ],
    );
    _values['session_1'] = session.toJson();
    _values['current_session_id'] = '1';
  }

  final _values = <String, Object?>{};

  @override
  Future<void> write(String key, Object? value) async => _values[key] = value;

  @override
  T? read<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Iterable<String> get keys => _values.keys;

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------- helpers

Future<void> loadFonts() async {
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

final screenshotsEnabled = Platform.environment['SCREENSHOTS'] == '1';
final boundaryKey = GlobalKey();

Future<void> saveScreenshot(WidgetTester tester, String name) async {
  final element = find.byKey(boundaryKey).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadFonts();
  });

  for (final locale in const [Locale('en'), Locale('ar'), Locale('bn')]) {
    for (final size in sizes) {
      for (final screen in screens) {
        // Bangla only needs a phone and a tablet pass.
        if (locale.languageCode == 'bn' &&
            !{'phone_360x800', 'tablet_800x1280'}.contains(size.name)) {
          continue;
        }
        final name = '${locale.languageCode}_${size.name}_${screen.name}';

        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(size.width, size.height);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = size.textScale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final problems = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString();
            problems.add(text.split('\n').first);
          };

          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: EasyLocalization(
                supportedLocales: const [
                  Locale('en'),
                  Locale('bn'),
                  Locale('ar'),
                ],
                path: 'assets/translations',
                fallbackLocale: const Locale('en'),
                startLocale: locale,
                saveLocale: false,
                child: ProviderScope(
                  overrides: [
                    localStorageProvider.overrideWithValue(
                      MemoryStorage(withSession: screen.withSession),
                    ),
                    bluetoothServiceProvider.overrideWithValue(FakeBluetooth()),
                    permissionServiceProvider.overrideWithValue(
                      GrantedPermissions(),
                    ),
                    magnetometerServiceProvider.overrideWithValue(
                      FakeMagnetometer(),
                    ),
                  ],
                  child: const ExamGuardApp(),
                ),
              ),
            ),
          );
          // Translations load from assets asynchronously.
          for (
            var i = 0;
            i < 20 && find.byType(MaterialApp).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(find.byType(MaterialApp), findsOneWidget);

          final router = ProviderScope.containerOf(
            tester.element(find.byType(ExamGuardApp)),
          ).read(appRouterProvider);
          router.go(screen.route, extra: screen.extra);
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 300));
          }

          if (Platform.environment['DEBUG_TREE'] == '1') {
            // ignore: avoid_print
            print(
              'TEXTS ${find.byType(Text).evaluate().length} '
              'SCAFFOLDS ${find.byType(Scaffold).evaluate().length} '
              'loc=${router.state.uri}',
            );
          }
          if (screenshotsEnabled) await saveScreenshot(tester, name);

          // Unmount so providers cancel their timers and subscriptions.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          FlutterError.onError = previous;

          expect(problems, isEmpty, reason: problems.toSet().join('\n'));
        });
      }
    }
  }
}
