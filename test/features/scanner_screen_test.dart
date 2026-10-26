// Widget tests for the wireless scanner screen: Location-off banner, grouped
// device card and the "filter matches nothing" empty state.
//
// Set SCREENSHOTS=1 to also write PNGs to build/screenshots/scanner_*.png.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view/widgets/location_off_banner.dart';
import 'package:exam_guard/features/scanner/view/widgets/professional_device_card.dart';
import 'package:exam_guard/features/scanner/view/widgets/scanner_empty_state.dart';
import 'package:exam_guard/features/scanner/view/widgets/walk_selection_bar.dart';
import 'package:exam_guard/features/scanner/view/wireless_scanner_screen.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBluetooth implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();
  final problems = StreamController<BleScanError?>.broadcast();

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {}

  @override
  Future<void> stopScan(String owner) async {}

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      const BleConnectionInfo();

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {}
}

class _Permissions implements IPermissionService {
  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;
  AppPermissionStatus status = AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> requestBluetoothScan() async => status;

  @override
  Future<bool> openSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

BleScanRecord _apple(String id, int rssi, {String name = ''}) => BleScanRecord(
  id: id,
  name: name,
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: const {
    0x004C: [0x10, 0x05, 0x01],
  },
  timestamp: DateTime.now(),
);

class _FakeClassic implements IClassicBluetoothService {
  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  final records = StreamController<ClassicBtRecord>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<ClassicBtRecord> get discoveries => records.stream;

  @override
  Future<void> start(String owner) async {}

  @override
  Future<void> stop(String owner) async {}

  @override
  Future<void> dispose() async {}
}

var _boundary = GlobalKey();

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

Future<void> _shot(WidgetTester tester, String name) async {
  if (Platform.environment['SCREENSHOTS'] != '1') return;
  final element = find.byKey(_boundary).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/scanner_$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeBluetooth bluetooth,
  _Permissions permissions, {
  ThemeMode themeMode = ThemeMode.light,
  IClassicBluetoothService? classic,
  bool expectScanning = true,
}) async {
  _boundary = GlobalKey();
  // Cached asset futures belong to the previous test's zone and never
  // complete in this one.
  rootBundle.clear();
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            bluetoothServiceProvider.overrideWithValue(bluetooth),
            permissionServiceProvider.overrideWithValue(permissions),
            if (classic != null)
              classicBluetoothServiceProvider.overrideWithValue(classic),
          ],
          child: Builder(
            builder: (context) => AppScreenSize(
              builder: (_) => MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const WirelessScannerScreen(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(WirelessScannerScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Wait until the scan is running, so no advertisement is missed.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(WirelessScannerScreen)),
  );
  for (
    var i = 0;
    i < 20 &&
        container.read(scannerViewModelProvider).isScanning != expectScanning;
    i++
  ) {
    await _settle(tester);
  }
  expect(container.read(scannerViewModelProvider).isScanning, expectScanning);
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

  testWidgets('Location off shows a banner that opens Location settings', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    final permissions = _Permissions();
    await _pumpScreen(
      tester,
      bluetooth,
      permissions,
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(LocationOffBanner), findsNothing);
    bluetooth.problems.add(BleScanError.locationOff);
    await _settle(tester);

    expect(find.byType(LocationOffBanner), findsOneWidget);
    final empty = tester.widget<ScannerEmptyState>(
      find.byType(ScannerEmptyState),
    );
    expect(empty.reason, ScannerEmptyReason.locationOff);
    await _shot(tester, 'location_off_dark');

    await tester.tap(
      find.descendant(
        of: find.byType(LocationOffBanner),
        matching: find.byType(FilledButton),
      ),
    );
    await _settle(tester);
    expect(permissions.locationSettingsOpened, 1);

    bluetooth.problems.add(null);
    await _settle(tester);
    expect(find.byType(LocationOffBanner), findsNothing);

    await _unmount(tester);
  });

  testWidgets('permanently denied permission offers Open Settings', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    final permissions = _Permissions()
      ..status = AppPermissionStatus.permanentlyDenied;
    await _pumpScreen(tester, bluetooth, permissions, expectScanning: false);
    await _settle(tester);

    final empty = tester.widget<ScannerEmptyState>(
      find.byType(ScannerEmptyState),
    );
    expect(empty.reason, ScannerEmptyReason.error);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Open Settings'));
    await _settle(tester);
    expect(permissions.appSettingsOpened, 1);

    await _unmount(tester);
  });

  testWidgets('one phone advertising three addresses is one expandable card', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    await _pumpScreen(tester, bluetooth, _Permissions());

    bluetooth.records
      ..add(_apple('AA:00:00:00:00:01', -49))
      ..add(_apple('AA:00:00:00:00:02', -50))
      ..add(_apple('AA:00:00:00:00:03', -49))
      ..add(_apple('BB:00:00:00:00:09', -70, name: 'Galaxy Watch6'));
    await _settle(tester);

    expect(find.byType(ProfessionalDeviceCard), findsNWidgets(2));
    final ids = find.textContaining(RegExp('AA:00:00:00:00:0[123]'));
    expect(ids, findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await _settle(tester);
    expect(ids, findsNWidgets(3));
    await _shot(tester, 'grouped_light');

    await _unmount(tester);
  });

  testWidgets('a filter that matches nothing offers "Show all"', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    await _pumpScreen(tester, bluetooth, _Permissions());

    bluetooth.records.add(_apple('AA:00:00:00:00:01', -80, name: 'iPhone'));
    await _settle(tester);
    expect(find.byType(ProfessionalDeviceCard), findsOneWidget);

    final espChip = find.text('scan_filter_esp32'.tr());
    await tester.ensureVisible(espChip);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(espChip);
    await _settle(tester);

    expect(find.byType(ProfessionalDeviceCard), findsNothing);
    final empty = find.byType(ScannerEmptyState);
    expect(
      tester.widget<ScannerEmptyState>(empty).reason,
      ScannerEmptyReason.filteredOut,
    );
    await _shot(tester, 'filtered_out_light');

    await tester.tap(
      find.descendant(of: empty, matching: find.byType(FilledButton)),
    );
    await _settle(tester);
    expect(find.byType(ProfessionalDeviceCard), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('classic devices show a badge and cannot be tracked on radar', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    final classic = _FakeClassic();
    await _pumpScreen(tester, bluetooth, _Permissions(), classic: classic);

    classic.records.add(
      ClassicBtRecord(
        address: '00:11:22:33:44:55',
        name: 'Nano Ear',
        rssi: -60,
        majorDeviceClass: 0x0400,
        deviceClass: 0x0404,
        timestamp: DateTime.now(),
      ),
    );
    bluetooth.records.add(_apple('AA:00:00:00:00:01', -80, name: 'iPhone'));
    await _settle(tester);

    expect(find.byType(ProfessionalDeviceCard), findsNWidgets(2));
    expect(find.text('scan_transport_classic'.tr()), findsOneWidget);
    expect(find.text('scan_high_suspicion'.tr()), findsOneWidget);

    final tracks = tester
        .widgetList<OutlinedButton>(
          find.descendant(
            of: find.byType(ProfessionalDeviceCard),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          ),
        )
        .toList();
    expect(tracks, hasLength(2));
    expect(tracks.where((b) => b.onPressed == null), hasLength(1));
    expect(find.byTooltip('scan_track_ble_only'.tr()), findsOneWidget);
    await _shot(tester, 'classic_light');

    await _unmount(tester);
  });

  testWidgets('long-press starts Walk & find selection; Cancel leaves it', (
    tester,
  ) async {
    final bluetooth = _FakeBluetooth();
    await _pumpScreen(tester, bluetooth, _Permissions());

    bluetooth.records
      ..add(_apple('AA:00:00:00:00:01', -60, name: 'iPhone'))
      ..add(_apple('BB:00:00:00:00:02', -70, name: 'Galaxy Watch6'));
    await _settle(tester);
    expect(find.byType(WalkSelectionBar), findsNothing);

    await tester.longPress(find.text('iPhone'));
    await _settle(tester);
    final bar = tester.widget<WalkSelectionBar>(find.byType(WalkSelectionBar));
    expect(bar.count, 1);
    expect(bar.max, 5);

    // While selecting, a tap picks instead of opening details.
    await tester.tap(find.text('Galaxy Watch6'));
    await _settle(tester);
    expect(
      tester.widget<WalkSelectionBar>(find.byType(WalkSelectionBar)).count,
      2,
    );
    await _shot(tester, 'selecting_light');

    await tester.tap(find.byTooltip('scan_select_cancel'.tr()));
    await _settle(tester);
    expect(find.byType(WalkSelectionBar), findsNothing);

    await _unmount(tester);
  });
}
