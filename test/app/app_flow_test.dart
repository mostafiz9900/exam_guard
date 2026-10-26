// End-to-end user journey through the real app widget tree (router,
// redirects, every screen) with all hardware faked and an in-memory store.
//
//   fvm flutter test test/app/app_flow_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:exam_guard/app/app_router.dart';
import 'package:exam_guard/app/exam_guard_app.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/core/settings/theme_mode_view_model.dart';
import 'package:exam_guard/features/action_log/view/action_entry_screen.dart';
import 'package:exam_guard/features/dashboard/view/dashboard_screen.dart';
import 'package:exam_guard/features/history/view/history_screen.dart';
import 'package:exam_guard/features/magnetic/view/magnetic_scanner_screen.dart';
import 'package:exam_guard/features/radar/view/tracking_radar_screen.dart';
import 'package:exam_guard/features/report/view/report_summary_screen.dart';
import 'package:exam_guard/features/rf_detector/view/rf_detector_screen.dart';
import 'package:exam_guard/features/scanner/view/wireless_scanner_screen.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view/session_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/radar/finder_fakes.dart';

// ---------------------------------------------------------------- fakes

class _Bluetooth implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();
  final owners = <String>{};

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Stream<BleScanError?> get scanProblem => Stream.value(null);

  @override
  Future<void> startScan(String owner) async {
    owners.add(owner);
    scheduleMicrotask(() {
      if (records.isClosed) return;
      for (final (id, name, rssi) in [
        ('B4:12:7A:9C:00:11', 'Galaxy Buds2 Pro', -58),
        ('F0:99:B6:21:7C:44', 'iPhone', -66),
      ]) {
        records.add(
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
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      const BleConnectionInfo();

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {}
}

class _Classic implements IClassicBluetoothService {
  final owners = <String>{};

  @override
  bool get isSupported => true;

  @override
  Stream<ClassicBtRecord> get discoveries => const Stream.empty();

  @override
  Future<void> start(String owner) async => owners.add(owner);

  @override
  Future<void> stop(String owner) async => owners.remove(owner);

  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  @override
  Future<void> dispose() async {}
}

class _Wifi implements IWifiScanService {
  final owners = <String>{};

  @override
  bool get isSupported => true;

  @override
  Stream<List<WifiNetworkRecord>> get results => const Stream.empty();

  @override
  Stream<WifiScanProblem?> get problem => Stream.value(null);

  @override
  Future<void> start(String owner) async => owners.add(owner);

  @override
  Future<void> stop(String owner) async => owners.remove(owner);

  @override
  Future<void> suspend(String key) async {}

  @override
  Future<void> resume(String key) async {}

  @override
  Future<void> dispose() async {}
}

class _Permissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Magnetometer implements IMagnetometerService {
  @override
  Stream<MagnetometerReading> readings() => Stream.fromIterable([
    for (var i = 0; i < 10; i++)
      MagnetometerReading(
        x: 20 + i.toDouble(),
        y: -18,
        z: 40,
        timestamp: DateTime.now(),
      ),
  ]);
}

class _Photos implements IPhotoService {
  @override
  Future<String?> takePhoto() async => null;

  @override
  Future<void> delete(String path) async {}

  @override
  Future<bool> exists(String path) async => false;
}

class _Share implements IShareService {
  final files = <String>[];
  final texts = <String>[];

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  }) async {
    files.add(fileName);
    return ShareOutcome.shared;
  }

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    texts.add(text);
    return ShareOutcome.shared;
  }
}

class _Pdf implements IPdfService {
  final documents = <PdfTableDocument>[];

  @override
  Future<Uint8List> buildTableDocument(PdfTableDocument document) async {
    documents.add(document);
    return Uint8List.fromList(const [37, 80, 68, 70]);
  }
}

class _MemoryStorage implements ILocalStorage {
  final values = <String, Object?>{};

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;

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

  List<SessionModel> get sessions => [
    for (final e in values.entries)
      if (e.key.startsWith('session_'))
        SessionModel.fromJson(
          Map<String, dynamic>.from(e.value! as Map<dynamic, dynamic>),
        ),
  ];
}

/// Every fake of one app run, kept so tests can inspect them.
class _Harness {
  _Harness(this.storage);

  final _MemoryStorage storage;
  final bluetooth = _Bluetooth();
  final classic = _Classic();
  final wifi = _Wifi();
  final wakelock = FakeWakelock();
  final haptics = FakeHaptics();
  final share = _Share();
  final pdf = _Pdf();

  late final overrides = [
    localStorageProvider.overrideWithValue(storage),
    bluetoothServiceProvider.overrideWithValue(bluetooth),
    classicBluetoothServiceProvider.overrideWithValue(classic),
    wifiScanServiceProvider.overrideWithValue(wifi),
    permissionServiceProvider.overrideWithValue(_Permissions()),
    magnetometerServiceProvider.overrideWithValue(_Magnetometer()),
    wakelockServiceProvider.overrideWithValue(wakelock),
    hapticServiceProvider.overrideWithValue(haptics),
    photoServiceProvider.overrideWithValue(_Photos()),
    shareServiceProvider.overrideWithValue(share),
    pdfServiceProvider.overrideWithValue(pdf),
  ];
}

// ---------------------------------------------------------------- helpers

final Map<String, Map<String, dynamic>> _translations = {
  for (final code in ['en', 'bn', 'ar'])
    code: jsonDecode(
      File('assets/translations/$code.json').readAsStringSync(),
    ) as Map<String, dynamic>,
};

/// English text of a translation key, with `{name}` placeholders filled.
String t(
  String key, {
  String lang = 'en',
  Map<String, String> args = const {},
}) {
  var text = _translations[lang]![key] as String;
  args.forEach((k, v) => text = text.replaceAll('{$k}', v));
  return text;
}

void _phoneScreen(WidgetTester tester, {double width = 400}) {
  tester.view.physicalSize = Size(width, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Advances fake time and lets real async work (asset loading) finish.
/// The dashboard animates forever, so pumpAndSettle can't be used.
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _launch(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: harness.overrides,
        child: const ExamGuardApp(),
      ),
    ),
  );
  // Translations load from assets and the router parses its first route
  // asynchronously; wait for the first screen.
  for (var i = 0; i < 100 && find.byType(Scaffold).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byType(MaterialApp), findsOneWidget);
  await settle(tester);
}

/// Unmounts the app so providers cancel their timers and subscriptions.
Future<void> shutDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

String _location(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ExamGuardApp)))
        .read(appRouterProvider)
        .state
        .uri
        .path;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder _field(String hint) => find.widgetWithText(TextField, hint);

Future<void> fillSetup(
  WidgetTester tester, {
  required String room,
  String institute = '',
  String teacher = '',
  String rows = '',
  String cols = '',
}) async {
  await tester.enterText(_field(t('room_hint')), room);
  if (institute.isNotEmpty) {
    await tester.enterText(_field(t('institute_hint')), institute);
  }
  if (teacher.isNotEmpty) {
    await tester.enterText(_field(t('supervisor_hint')), teacher);
  }
  if (rows.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('seat_rows')), rows);
  }
  if (cols.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('seat_cols')), cols);
  }
  await tester.pump();
}

/// Opens a dashboard module by its card title and returns with the app bar
/// back button.
Future<void> openModuleAndBack(
  WidgetTester tester,
  String titleKey,
  Type screen,
) async {
  await tapVisible(tester, find.text(t(titleKey)).first);
  expect(find.byType(screen), findsOneWidget, reason: titleKey);
  await tester.pageBack();
  await settle(tester);
  expect(find.byType(DashboardScreen), findsOneWidget, reason: titleKey);
  expect(find.byType(screen), findsNothing, reason: titleKey);
}

Future<void> chooseMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.tune).last);
  await settle(tester, frames: 3);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

/// Real Roboto/Material Icons metrics (as in test/responsive), so overflow
/// checks don't depend on the square Ahem test font.
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

// ---------------------------------------------------------------- tests

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  // CachingAssetBundle keeps the translation futures of the previous test,
  // bound to that test's (finished) FakeAsync zone: awaiting them again
  // never completes and the next test hangs on a blank Localizations.
  setUp(rootBundle.clear);

  testWidgets('full exam journey: setup → modules → incident → end → report '
      '→ history → new exam', (tester) async {
    _phoneScreen(tester);
    final harness = _Harness(_MemoryStorage());

    // Launch → no session → setup screen.
    await _launch(tester, harness);
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    expect(_location(tester), AppRoute.sessionSetup);
    expect(find.text(t('view_last_report')), findsNothing);

    // Room is required.
    await tapVisible(tester, find.text(t('start_session')));
    expect(find.text(t('room_required')), findsOneWidget);
    expect(find.byType(SessionSetupScreen), findsOneWidget);

    // A half-filled seat layout is rejected.
    await fillSetup(tester, room: '302-B', rows: '4');
    await tapVisible(tester, find.text(t('start_session')));
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    expect(harness.storage.sessions, isEmpty);

    await fillSetup(
      tester,
      room: '302-B',
      institute: 'Central College',
      teacher: 'Dr. Rahman',
      rows: '4',
      cols: '5',
    );
    await tapVisible(tester, find.text(t('start_session')));

    // Dashboard, session persisted.
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(_location(tester), AppRoute.dashboard);
    expect(find.text(t('room', args: {'room': '302-B'})), findsWidgets);
    final started = harness.storage.sessions.single;
    expect(started.roomNumber, '302-B');
    expect(started.instituteName, 'Central College');
    expect(started.teacherName, 'Dr. Rahman');
    expect((started.seatRows, started.seatCols), (4, 5));
    expect(started.isActive, isTrue);
    expect(harness.bluetooth.owners, isNotEmpty, reason: 'scanning live');

    // Every module opens and returns to the dashboard.
    await openModuleAndBack(tester, 'wireless_scan', WirelessScannerScreen);
    await openModuleAndBack(tester, 'tracking_radar', TrackingRadarScreen);
    await openModuleAndBack(tester, 'magnetic_scan', MagneticScannerScreen);
    await openModuleAndBack(tester, 'rf_meter', RfDetectorScreen);
    await openModuleAndBack(tester, 'report', ReportSummaryScreen);

    // History is closed while the exam runs: redirected to the dashboard.
    ProviderScope.containerOf(tester.element(find.byType(ExamGuardApp)))
        .read(appRouterProvider)
        .go(AppRoute.history);
    await settle(tester);
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Log an incident manually.
    await tapVisible(tester, find.text(t('log_incident')).first);
    expect(find.text(t('incident_form_title')), findsOneWidget);
    await tester.enterText(
      _field(t('incident_device_name_hint')),
      'Hidden earpiece',
    );
    await tester.enterText(
      _field(t('incident_location_note_hint')),
      'Back row',
    );
    await tapVisible(tester, find.text(t('save_record')));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(_location(tester), AppRoute.dashboard);
    final logs = harness.storage.sessions.single.deviceLogs;
    expect(logs.single.deviceName, 'Hidden earpiece');
    expect(logs.single.location, 'Back row');

    // End exam: cancel first, then confirm.
    await tapVisible(tester, find.text(t('end_exam')));
    expect(find.text(t('end_exam_title')), findsOneWidget);
    await tester.tap(find.text(t('cancel')));
    await settle(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(harness.storage.sessions.single.isActive, isTrue);

    await tapVisible(tester, find.text(t('end_exam')));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(t('end_exam')),
      ),
    );
    await settle(tester);

    // Report summary shows the incident; the exam is saved as ended.
    expect(find.byType(ReportSummaryScreen), findsOneWidget);
    expect(_location(tester), AppRoute.report);
    expect(find.text('Hidden earpiece'), findsWidgets);
    final ended = harness.storage.sessions.single;
    expect(ended.isActive, isFalse);
    expect(ended.endTime, isNotNull);
    expect(ended.deviceLogs, hasLength(1));
    expect(harness.bluetooth.owners, isEmpty, reason: 'scan stopped');

    // Export the PDF report through the share sheet.
    await tapVisible(tester, find.text(t('report_export_share')));
    expect(harness.pdf.documents, hasLength(1));
    expect(harness.share.files.single, endsWith('.pdf'));

    // Exam screens are closed after the exam ended.
    ProviderScope.containerOf(tester.element(find.byType(ExamGuardApp)))
        .read(appRouterProvider)
        .go(AppRoute.dashboard);
    await settle(tester);
    expect(find.byType(ReportSummaryScreen), findsOneWidget);

    // New exam session → setup, then history shows the saved exam.
    await tapVisible(tester, find.text(t('report_new_session')));
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    expect(find.text(t('view_last_report')), findsOneWidget);

    await tapVisible(tester, find.text(t('setup_exam_history')));
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text(t('room', args: {'room': '302-B'})), findsOneWidget);
    expect(find.text(t('incidents_count', args: {'count': '1'})), findsWidgets);

    // Opening the saved exam shows its report.
    await tapVisible(tester, find.text(t('room', args: {'room': '302-B'})));
    expect(find.byType(ReportSummaryScreen), findsOneWidget);
    expect(find.text('Hidden earpiece'), findsWidgets);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(SessionSetupScreen), findsOneWidget);

    // Start a new exam.
    await fillSetup(tester, room: '105');
    await tapVisible(tester, find.text(t('start_session')));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text(t('room', args: {'room': '105'})), findsWidgets);
    final sessions = harness.storage.sessions;
    expect(sessions, hasLength(2));
    expect(sessions.where((s) => s.isActive).single.roomNumber, '105');
    expect(
      sessions.where((s) => s.isActive).single.deviceLogs,
      isEmpty,
      reason: 'a new exam starts without the old incidents',
    );

    await shutDown(tester);
  });

  testWidgets('saving an incident returns to the dashboard', (tester) async {
    // Regression: a router refresh on every session edit re-created the
    // pushed form, so its pop after saving never closed it.
    _phoneScreen(tester);
    final harness = _Harness(_MemoryStorage());
    await _launch(tester, harness);
    await fillSetup(tester, room: '1');
    await tapVisible(tester, find.text(t('start_session')));
    await tapVisible(tester, find.text(t('log_incident')).first);
    await tester.enterText(_field(t('incident_device_name_hint')), 'X');
    await tapVisible(tester, find.text(t('save_record')));

    expect(harness.storage.sessions.single.deviceLogs.single.deviceName, 'X');
    expect(find.byType(ActionEntryScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(_location(tester), AppRoute.dashboard);
    await shutDown(tester);
  });

  testWidgets('relaunch with a running exam restores the dashboard', (
    tester,
  ) async {
    _phoneScreen(tester);
    final storage = _MemoryStorage();

    await _launch(tester, _Harness(storage));
    await fillSetup(tester, room: '12/B');
    await tapVisible(tester, find.text(t('start_session')));
    expect(find.byType(DashboardScreen), findsOneWidget);
    await shutDown(tester);

    // Same storage, fresh providers: like a process restart.
    await _launch(tester, _Harness(storage));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(_location(tester), AppRoute.dashboard);
    expect(find.text(t('room', args: {'room': '12/B'})), findsWidgets);

    // After ending, a relaunch lands on setup with the last report offered.
    await tapVisible(tester, find.text(t('end_exam')));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(t('end_exam')),
      ),
    );
    await settle(tester);
    expect(find.byType(ReportSummaryScreen), findsOneWidget);
    await shutDown(tester);

    await _launch(tester, _Harness(storage));
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    await tapVisible(tester, find.text(t('view_last_report')));
    expect(find.byType(ReportSummaryScreen), findsOneWidget);

    await shutDown(tester);
  });

  Future<void> languageJourney(WidgetTester tester, double width) async {
    _phoneScreen(tester, width: width);
    final harness = _Harness(_MemoryStorage());
    await _launch(tester, harness);

    TextDirection direction() =>
        Directionality.of(tester.element(find.byType(Scaffold).first));

    // Setup screen.
    expect(find.text(t('start_session')), findsOneWidget);
    await chooseMenu(tester, t('bangla'));
    expect(find.text(t('start_session', lang: 'bn')), findsOneWidget);
    expect(direction(), TextDirection.ltr);
    await chooseMenu(tester, t('arabic'));
    expect(find.text(t('start_session', lang: 'ar')), findsOneWidget);
    expect(direction(), TextDirection.rtl);

    // Start the exam in Arabic (fields by order: room first).
    await tester.enterText(find.byType(TextField).first, '204');
    await tapVisible(tester, find.text(t('start_session', lang: 'ar')));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text(t('dashboard', lang: 'ar')), findsOneWidget);
    expect(direction(), TextDirection.rtl);

    // Dashboard back to Bangla, then English.
    await chooseMenu(tester, t('bangla', lang: 'ar'));
    expect(find.text(t('dashboard', lang: 'bn')), findsOneWidget);
    expect(direction(), TextDirection.ltr);
    await chooseMenu(tester, t('english', lang: 'bn'));
    expect(find.text(t('dashboard')), findsOneWidget);

    await shutDown(tester);
  }

  testWidgets(
    'language switch en → bn → ar on setup and dashboard (360 dp)',
    (tester) => languageJourney(tester, 360),
  );

  testWidgets(
    'language switch en → bn → ar on setup and dashboard (400 dp)',
    (tester) => languageJourney(tester, 400),
  );

  testWidgets('dark mode toggle applies everywhere and is remembered', (
    tester,
  ) async {
    _phoneScreen(tester);
    final storage = _MemoryStorage();
    await _launch(tester, _Harness(storage));

    Brightness brightness() =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    await chooseMenu(tester, t('dark_theme'));
    expect(brightness(), Brightness.dark);
    expect(storage.read<String>(ThemeModeViewModel.storageKey), 'dark');

    await fillSetup(tester, room: '7');
    await tapVisible(tester, find.text(t('start_session')));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(brightness(), Brightness.dark);

    await chooseMenu(tester, t('light_theme'));
    expect(brightness(), Brightness.light);
    await chooseMenu(tester, t('dark_theme'));
    await shutDown(tester);

    // Remembered across a restart.
    await _launch(tester, _Harness(storage));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(brightness(), Brightness.dark);

    await shutDown(tester);
  });
}
