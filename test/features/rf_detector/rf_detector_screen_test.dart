// RF activity meter screen: small-phone rendering (light/dark), explicit
// not-measuring states (never "quiet" without a scan), threat level driven by
// fake packets, the shared buzzer, the guide sheet and the incident hand-off.
// No real radio, permission or audio plugin is touched.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/rf_detector/model/rf_threat_level.dart';
import 'package:exam_guard/features/rf_detector/view/rf_detector_screen.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/guide_step_tile.dart';
import 'package:exam_guard/features/rf_detector/view/widgets/rf_wave_painter.dart';
import 'package:exam_guard/features/rf_detector/view_model/rf_detector_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

class _FakeBluetooth implements IBluetoothService {

  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();
  final adapter = StreamController<BleAdapterStatus>.broadcast();
  final problems = StreamController<BleScanError?>.broadcast();
  BleAdapterStatus status = BleAdapterStatus.on;
  final owners = <String>{};
  Object? startError;
  Object? stopError;
  var startCalls = 0;
  var stopCalls = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() async* {
    yield status;
    yield* adapter.stream;
  }

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {
    startCalls++;
    if (startError != null) throw startError!;
    owners.add(owner);
  }

  @override
  Future<void> stopScan(String owner) async {
    stopCalls++;
    owners.remove(owner);
    if (stopError != null) throw stopError!;
  }

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      throw Exception('not supported');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {}
}

class _FakePermissions implements IPermissionService {
  AppPermissionStatus status = AppPermissionStatus.granted;
  var requests = 0;
  var locationSettingsOpened = 0;

  /// When set, the request waits for this before answering.
  Future<void>? gate;

  @override
  Future<AppPermissionStatus> requestBluetoothScan() async {
    requests++;
    if (gate != null) await gate;
    return status;
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

class _FakeClassic implements IClassicBluetoothService {
  final suspended = <String>{};

  @override
  bool get isSupported => false;

  @override
  Stream<ClassicBtRecord> get discoveries => const Stream.empty();

  @override
  Future<void> start(String owner) async {}

  @override
  Future<void> stop(String owner) async {}

  @override
  Future<void> suspend(String key) async => suspended.add(key);

  @override
  Future<void> resume(String key) async => suspended.remove(key);

  @override
  Future<void> dispose() async {}
}

class _FakeWifi implements IWifiScanService {
  final suspended = <String>{};

  @override
  bool get isSupported => false;

  @override
  Stream<List<WifiNetworkRecord>> get results => const Stream.empty();

  @override
  Stream<WifiScanProblem?> get problem => const Stream.empty();

  @override
  Future<void> start(String owner) async {}

  @override
  Future<void> stop(String owner) async {}

  @override
  Future<void> suspend(String key) async => suspended.add(key);

  @override
  Future<void> resume(String key) async => suspended.remove(key);

  @override
  Future<void> dispose() async {}
}

/// Records buzzer calls instead of playing sounds/haptics.
class _FakeBuzzer implements GeigerBuzzerService {
  final distances = <double>[];
  var stops = 0;

  /// True while a Geiger loop would be running.
  bool beeping = false;

  @override
  bool get isEnabled => true;

  @override
  void toggleAudio(bool enabled) {}

  @override
  void updateTargetDistance(double distanceMeters) {
    distances.add(distanceMeters);
    beeping = true;
  }

  @override
  void stopBuzzer() {
    stops++;
    beeping = false;
  }

  @override
  void playAlert({
    int clicks = 4,
    Duration gap = const Duration(milliseconds: 110),
  }) {}

  @override
  void stopAlert() {}

  @override
  bool get isAlertPlaying => false;
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
}

BleScanRecord _packet(
  String id,
  int rssi, {
  String name = '',
  DateTime? at,
}) => BleScanRecord(
  id: id,
  name: name,
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: const {},
  timestamp: at ?? DateTime.now(),
);

// ---------------------------------------------------------------- harness

const _quietGreen = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);

class _Harness {
  final bluetooth = _FakeBluetooth();
  final permissions = _FakePermissions();
  final classic = _FakeClassic();
  final wifi = _FakeWifi();
  final buzzer = _FakeBuzzer();
  final pushedArgs = <ActionEntryArgs?>[];
  late ProviderContainer container;

  RfDetectorState get state => container.read(rfDetectorViewModelProvider);

  RfDetectorViewModel get vm =>
      container.read(rfDetectorViewModelProvider.notifier);

  /// Opens the RF meter. With [viaHome] the meter is pushed on top of a stub
  /// home screen so it can be left with the back button.
  Future<void> pump(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    bool viaHome = false,
  }) async {
    rootBundle.clear();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: viaHome ? '/' : AppRoute.rfDetector,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(AppRoute.rfDetector),
                child: const Text('open rf'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.rfDetector,
          builder: (_, _) => const RfDetectorScreen(),
        ),
        GoRoute(
          path: AppRoute.actionNew,
          builder: (context, routerState) {
            pushedArgs.add(routerState.extra as ActionEntryArgs?);
            return Scaffold(
              appBar: AppBar(title: const Text('incident form')),
            );
          },
        ),
        GoRoute(
          path: AppRoute.dashboard,
          builder: (_, _) => const Scaffold(body: Text('dashboard stub')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(_MemoryStorage()),
            bluetoothServiceProvider.overrideWithValue(bluetooth),
            permissionServiceProvider.overrideWithValue(permissions),
            classicBluetoothServiceProvider.overrideWithValue(classic),
            wifiScanServiceProvider.overrideWithValue(wifi),
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
    final target = viaHome ? find.text('open rf') : find.byType(RfDetectorScreen);
    for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (viaHome) {
      await tester.tap(find.text('open rf'));
      await tester.pumpAndSettle();
    }
    container = ProviderScope.containerOf(
      tester.element(find.byType(RfDetectorScreen)),
    );
    await settleStart(tester);
  }

  /// Lets the microtask-started scan finish.
  Future<void> settleStart(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  /// Sends packets and runs one 250 ms meter tick.
  Future<void> feed(WidgetTester tester, List<BleScanRecord> packets) async {
    for (final p in packets) {
      bluetooth.records.add(p);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
  }
}

/// The big dBm read-out inside the gauge.
Text _gaugeText(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).where(
    (t) => t.style?.fontFamily == 'monospace',
  );
  return texts.single;
}

Finder _textContaining(String s) => find.textContaining(s, findRichText: true);

Future<void> _leaveScreen(WidgetTester tester) async {
  // Dispose the tree: autoDispose VM runs its cleanup.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  // ------------------------------------------------------------ rendering

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders live meter on a small phone without overflow ($mode)', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester, mode: mode);
      expect(find.text('RF activity meter'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('QUIET (below -70 dBm)'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      // Scroll through everything to lay it all out.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(find.text('Log incident'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Strong signal state renders too.
      await h.feed(tester, [_packet('AA', -40, name: 'Hidden earbud')]);
      expect(tester.takeException(), isNull);
      await _leaveScreen(tester);
    });

    testWidgets('not-measuring state renders without overflow ($mode)', (
      tester,
    ) async {
      final h = _Harness()..bluetooth.status = BleAdapterStatus.off;
      await h.pump(tester, mode: mode);
      expect(_textContaining('NOT MEASURING'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _leaveScreen(tester);
    });
  }

  // ------------------------------------------------- not-measuring states

  group('not measuring is never shown as quiet', () {
    void expectNotQuiet(WidgetTester tester, _Harness h) {
      expect(find.textContaining('QUIET'), findsNothing);
      expect(find.text('LIVE'), findsNothing);
      expect(find.text('STOPPED'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
      expect(_textContaining('NOT MEASURING'), findsOneWidget);
      expect(_gaugeText(tester).data, '--');
      // Grey, not the green "all clear".
      final outline = Theme.of(
        tester.element(find.byType(RfDetectorScreen)),
      ).colorScheme.outline;
      expect(_gaugeText(tester).style?.color, outline);
      expect(_gaugeText(tester).style?.color, isNot(_quietGreen));
    }

    testWidgets('Bluetooth off shows banner and Retry restarts the scan', (
      tester,
    ) async {
      final h = _Harness()..bluetooth.status = BleAdapterStatus.off;
      await h.pump(tester);
      expectNotQuiet(tester, h);
      expect(h.state.isBluetoothOff, isTrue);
      expect(
        find.text('Bluetooth is off. Turn it on to measure RF.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Turn Bluetooth on (quick settings)'),
        findsOneWidget,
      );
      expect(h.bluetooth.owners, isEmpty);

      h.bluetooth.status = BleAdapterStatus.on;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await h.settleStart(tester);
      expect(h.state.isMeasuring, isTrue);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('QUIET (below -70 dBm)'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(h.bluetooth.owners, contains('rf_detector'));
      await _leaveScreen(tester);
    });

    testWidgets('permission denied shows banner and Retry asks again', (
      tester,
    ) async {
      final h = _Harness()..permissions.status = AppPermissionStatus.denied;
      await h.pump(tester);
      expectNotQuiet(tester, h);
      expect(
        find.text('Bluetooth/Location permission is required.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('A quiet meter here does not mean'),
        findsOneWidget,
      );
      expect(h.permissions.requests, 1);

      h.permissions.status = AppPermissionStatus.granted;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await h.settleStart(tester);
      expect(h.permissions.requests, 2);
      expect(h.state.isMeasuring, isTrue);
      expect(find.text('LIVE'), findsOneWidget);
      await _leaveScreen(tester);
    });

    testWidgets('Location off shows banner with Turn on Location', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.feed(tester, [_packet('AA', -40)]);
      expect(h.state.threatLevel, RfThreatLevel.strong);

      h.bluetooth.problems.add(BleScanError.locationOff);
      await tester.pump();
      await tester.pump();
      expectNotQuiet(tester, h);
      expect(_textContaining('Location is off'), findsOneWidget);
      expect(find.textContaining('Measuring resumes automatically'),
          findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(h.buzzer.beeping, isFalse);

      // Ticks while Location is off keep the not-measuring state.
      await h.feed(tester, [_packet('AA', -30)]);
      expect(h.state.isMeasuring, isFalse);
      expect(h.state.currentDbm, isNull);

      await tester.ensureVisible(find.text('Turn on Location'));
      await tester.tap(find.text('Turn on Location'));
      await tester.pump();
      expect(h.permissions.locationSettingsOpened, 1);

      h.bluetooth.problems.add(null);
      await tester.pump();
      await tester.pump();
      expect(h.state.isMeasuring, isTrue);
      expect(find.text('LIVE'), findsOneWidget);
      await _leaveScreen(tester);
    });

    testWidgets('Location off reported by startScan keeps the scan registered',
        (tester) async {
      final h = _Harness()
        ..bluetooth.startError = const BleScanException(
          'Location off',
          code: BleScanError.locationOff,
        );
      await h.pump(tester);
      expect(h.state.isLocationOff, isTrue);
      expect(h.state.isScanning, isTrue);
      expect(h.state.isMeasuring, isFalse);
      expect(find.text('Turn on Location'), findsOneWidget);
      expect(find.textContaining('QUIET'), findsNothing);

      h.bluetooth.problems.add(null);
      await tester.pump();
      await tester.pump();
      expect(h.state.isMeasuring, isTrue);
      await _leaveScreen(tester);
    });
  });

  // -------------------------------------------------------- threat levels

  testWidgets('signals move the threat level, label and colours', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(h.state.threatLevel, RfThreatLevel.quiet);
    expect(_gaugeText(tester).style?.color, _quietGreen);

    // Weak signal: still quiet but measured.
    await h.feed(tester, [_packet('AA', -85, name: 'Far phone')]);
    expect(h.state.threatLevel, RfThreatLevel.quiet);
    expect(_gaugeText(tester).data, '-85');
    expect(find.text('QUIET (below -70 dBm)'), findsOneWidget);
    expect(
      find.text('1 transmitters • 1 packets/s • strongest: Far phone'),
      findsOneWidget,
    );

    // Moderate.
    await h.feed(tester, [_packet('BB', -60)]);
    expect(h.state.threatLevel, RfThreatLevel.moderate);
    expect(
      find.text('ACTIVE TRANSMITTER NEARBY (-70 to -50 dBm)'),
      findsOneWidget,
    );
    expect(_gaugeText(tester).style?.color, _amber);
    // Unnamed source falls back to its id.
    expect(h.state.strongestSourceName, 'BB');
    expect(h.state.activeTransmitters, 2);

    // Strong.
    await h.feed(tester, [_packet('CC', -42, name: 'Earbud')]);
    expect(h.state.threatLevel, RfThreatLevel.strong);
    expect(
      find.text('STRONG TRANSMITTER VERY CLOSE (above -50 dBm)'),
      findsOneWidget,
    );
    expect(_gaugeText(tester).style?.color, _red);
    expect(find.text('Peak: -42 dBm'), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<RfWavePainter>()
        .single;
    expect(painter.color, _red);
    expect(painter.history.length, greaterThanOrEqualTo(3));
    await _leaveScreen(tester);
  });

  testWidgets('old packets age out so a strong reading falls back to quiet', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    // Almost out of the 2 s window already.
    await h.feed(tester, [
      _packet(
        'AA',
        -40,
        at: DateTime.now().subtract(const Duration(milliseconds: 1850)),
      ),
    ]);
    expect(h.state.threatLevel, RfThreatLevel.strong);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 260));
    expect(h.state.threatLevel, RfThreatLevel.quiet);
    expect(h.state.currentDbm, isNull);
    // Peak is kept, gauge shows "--" while silent.
    expect(h.state.peakDbm, -40);
    expect(_gaugeText(tester).data, '--');
    expect(find.text('0 transmitters • 0 packets/s'), findsOneWidget);
    await _leaveScreen(tester);
  });

  testWidgets('Reset peak sets the peak to the current reading', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await h.feed(tester, [_packet('AA', -45)]);
    await h.feed(tester, [_packet('BB', -45)]);
    expect(h.state.peakDbm, -45);
    await tester.ensureVisible(find.text('Reset peak'));
    await tester.tap(find.text('Reset peak'));
    await tester.pump();
    expect(h.state.peakDbm, h.state.currentDbm);
    await _leaveScreen(tester);
  });

  testWidgets('ExamGuard hardware node shows the node badge', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.feed(tester, [_packet('NN', -80, name: 'ExamGuard-Node-1')]);
    expect(h.state.hardwareNodeName, 'ExamGuard-Node-1');
    expect(find.text('EXAMGUARD NODE NEARBY'), findsOneWidget);
    expect(find.text('ExamGuard-Node-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _leaveScreen(tester);
  });

  // --------------------------------------------------------------- buzzer

  testWidgets('buzzer follows the threat level and stops on leave', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester, viaHome: true);
    expect(h.state.isMeasuring, isTrue);

    await h.feed(tester, [_packet('AA', -60)]);
    expect(h.buzzer.distances, isEmpty);
    expect(h.buzzer.beeping, isFalse);

    await h.feed(tester, [_packet('BB', -40)]);
    expect(h.buzzer.distances, isNotEmpty);
    expect(h.buzzer.distances.last, 1.0);
    expect(h.buzzer.beeping, isTrue);

    // Mute via the app bar: beeps stop and no new ones start.
    await tester.tap(find.byTooltip('Audio beep on/off'));
    await tester.pump();
    expect(h.state.isBuzzerEnabled, isFalse);
    expect(h.buzzer.beeping, isFalse);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    final before = h.buzzer.distances.length;
    await h.feed(tester, [_packet('BB', -40)]);
    expect(h.buzzer.distances.length, before);

    // Unmute: beeps resume.
    await tester.tap(find.byTooltip('Audio beep on/off'));
    await tester.pump();
    await h.feed(tester, [_packet('BB', -40)]);
    expect(h.buzzer.beeping, isTrue);

    // Leaving the screen with the back button stops the buzzer and scan.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(RfDetectorScreen), findsNothing);
    expect(find.text('open rf'), findsOneWidget);
    expect(h.buzzer.beeping, isFalse);
    expect(h.bluetooth.owners, isEmpty);
    expect(h.classic.suspended, isEmpty);
    expect(h.wifi.suspended, isEmpty);
  });

  testWidgets('back without a page underneath goes to the dashboard', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('dashboard stub'), findsOneWidget);
    expect(h.bluetooth.owners, isEmpty);
  });

  testWidgets('stopScanning silences the buzzer and shows stopped', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await h.feed(tester, [_packet('AA', -40)]);
    expect(h.buzzer.beeping, isTrue);
    final stopsBefore = h.buzzer.stops;
    h.vm.stopScanning();
    await tester.pump();
    expect(h.buzzer.stops, greaterThan(stopsBefore));
    expect(h.buzzer.beeping, isFalse);
    expect(h.state.isScanning, isFalse);
    expect(find.text('STOPPED'), findsOneWidget);
    expect(_textContaining('scan stopped'), findsOneWidget);
    await _leaveScreen(tester);
  });

  // ---------------------------------------------------------------- guide

  testWidgets('guide sheet shows the three steps and closes', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.byTooltip('RF meter guide'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideStepTile), findsNWidgets(3));
    expect(find.text('What this meter measures'), findsOneWidget);
    expect(find.text('Finding a hidden transmitter'), findsOneWidget);
    expect(find.text('ExamGuard hardware node'), findsOneWidget);
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    final done = find.text('Got it, continue monitoring');
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byType(GuideStepTile), findsNothing);
    await _leaveScreen(tester);
  });

  // ------------------------------------------------------------ incident

  testWidgets('Log incident pushes the form with alerts suspended', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await h.feed(tester, [_packet('AA', -40, name: 'Earbud')]);
    expect(h.buzzer.beeping, isTrue);

    await tester.ensureVisible(find.text('Log incident'));
    await tester.tap(find.text('Log incident'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('incident form'), findsOneWidget);
    expect(h.buzzer.beeping, isFalse);

    final args = h.pushedArgs.last!;
    expect(args.category, 'RF Transmitter');
    expect(args.notes, contains('RF meter: strongest -40 dBm from Earbud'));
    expect(args.notes, contains(RfThreatLevel.strong.label));
    expect(args.notes, contains('1 transmitters'));

    // Ticks under the form keep the buzzer silent.
    final before = h.buzzer.distances.length;
    await h.feed(tester, [_packet('AA', -40, name: 'Earbud')]);
    await h.feed(tester, [_packet('AA', -40, name: 'Earbud')]);
    expect(h.buzzer.distances.length, before);
    expect(h.buzzer.beeping, isFalse);

    // Back on the meter: alerts resume.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('incident form'), findsNothing);
    await h.feed(tester, [_packet('AA', -40, name: 'Earbud')]);
    expect(h.buzzer.distances.length, greaterThan(before));
    expect(h.buzzer.beeping, isTrue);
    await _leaveScreen(tester);
  });

  testWidgets('Log incident while not measuring records the reason', (
    tester,
  ) async {
    final h = _Harness()..bluetooth.status = BleAdapterStatus.off;
    await h.pump(tester);
    await tester.ensureVisible(find.text('Log incident'));
    await tester.tap(find.text('Log incident'));
    await tester.pumpAndSettle();
    expect(
      h.pushedArgs.last!.notes,
      'RF meter: not measuring when logged (Bluetooth is off).',
    );
    await _leaveScreen(tester);
  });

  // --------------------------------------------- view-model branch coverage

  group('view model', () {
    testWidgets('adapter unauthorized / unavailable / unknown', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      h.bluetooth.adapter.add(BleAdapterStatus.unknown);
      await tester.pump();
      expect(h.state.isMeasuring, isTrue);

      h.bluetooth.adapter.add(BleAdapterStatus.unauthorized);
      await tester.pump();
      expect(h.state.errorKey, RfDetectorViewModel.permissionErrorKey);
      expect(h.bluetooth.owners, isEmpty);

      h.bluetooth.adapter.add(BleAdapterStatus.unavailable);
      await tester.pump();
      expect(h.state.errorKey, RfDetectorViewModel.noRadioErrorKey);
      await tester.pump();
      expect(
        find.text('This phone has no usable Bluetooth radio.'),
        findsOneWidget,
      );

      // Adapter errors are logged, not fatal.
      h.bluetooth.adapter.addError(Exception('adapter'));
      await tester.pump();
      expect(h.state.errorKey, RfDetectorViewModel.noRadioErrorKey);
      await _leaveScreen(tester);
    });

    testWidgets('throttled scan start shows the throttle reason', (
      tester,
    ) async {
      final h = _Harness()
        ..bluetooth.startError = const BleScanException(
          'throttled',
          code: BleScanError.throttled,
        );
      await h.pump(tester);
      expect(h.state.errorKey, RfDetectorViewModel.scanThrottledErrorKey);
      expect(find.textContaining('Android paused scanning'), findsNWidgets(2));
      await _leaveScreen(tester);
    });

    testWidgets('unexpected start error shows "could not start"', (
      tester,
    ) async {
      final h = _Harness()..bluetooth.startError = StateError('boom');
      await h.pump(tester);
      expect(h.state.errorKey, RfDetectorViewModel.scanStartErrorKey);
      expect(
        find.text('Could not start the Bluetooth scan.'),
        findsOneWidget,
      );
      expect(h.vm.incidentNotes(), contains('could not start'));
      await _leaveScreen(tester);
    });

    testWidgets('non-BLE stream error maps to scan failed', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.bluetooth.records.addError(StateError('radio'));
      await tester.pump();
      expect(h.state.errorKey, RfDetectorViewModel.scanFailedErrorKey);
      expect(h.bluetooth.owners, isEmpty);
      await _leaveScreen(tester);
    });

    testWidgets('scanErrorKey mapping', (tester) async {
      expect(
        RfDetectorViewModel.scanErrorKey(
          const BleScanException('x', code: BleScanError.locationOff),
        ),
        RfDetectorViewModel.locationOffErrorKey,
      );
      expect(
        RfDetectorViewModel.scanErrorKey(
          const BleScanException('x', code: BleScanError.throttled),
        ),
        RfDetectorViewModel.scanThrottledErrorKey,
      );
      expect(
        RfDetectorViewModel.scanErrorKey(const BleScanException('x')),
        RfDetectorViewModel.scanFailedErrorKey,
      );
    });

    testWidgets('scan problem stream errors are ignored', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.bluetooth.problems.addError(Exception('problem'));
      await tester.pump();
      expect(h.state.isMeasuring, isTrue);
      // A non-location problem while measuring changes nothing.
      h.bluetooth.problems.add(BleScanError.throttled);
      await tester.pump();
      expect(h.state.isMeasuring, isTrue);
      await _leaveScreen(tester);
    });

    testWidgets('stopScanning while Location is off clears the reason', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      h.bluetooth.problems.add(BleScanError.locationOff);
      await tester.pump();
      expect(h.state.isLocationOff, isTrue);
      h.vm.stopScanning();
      await tester.pump();
      expect(h.state.isLocationOff, isFalse);
      expect(h.state.errorKey, isNull);
      expect(h.state.isMeasuring, isFalse);
      expect(_textContaining('scan stopped'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await _leaveScreen(tester);
    });

    testWidgets('stopScan failures are logged, not thrown', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.bluetooth.stopError = Exception('stop failed');
      // _notMeasuring path.
      h.bluetooth.adapter.add(BleAdapterStatus.off);
      await tester.pump();
      expect(h.state.isBluetoothOff, isTrue);
      // Restart, then _stop path on dispose.
      h.bluetooth.adapter.add(BleAdapterStatus.on);
      await h.settleStart(tester);
      expect(h.state.isMeasuring, isTrue);
      await _leaveScreen(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('incident notes without a source', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(
        h.vm.incidentNotes(),
        'RF meter: strongest -- dBm from no source (peak -- dBm), '
        '0 transmitters, 0 packets/s, ${RfThreatLevel.quiet.label}.',
      );
      await _leaveScreen(tester);
    });

    testWidgets('state shows "starting" while permission is pending', (
      tester,
    ) async {
      final gate = Completer<void>();
      final h = _Harness()..permissions.gate = gate.future;
      await h.pump(tester);
      expect(h.state.isStarting, isTrue);
      expect(find.text('STARTING BLUETOOTH SCAN…'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      // A second start while starting is ignored.
      await h.vm.startScanning();
      expect(h.permissions.requests, 1);
      gate.complete();
      await h.settleStart(tester);
      expect(h.state.isMeasuring, isTrue);
      await _leaveScreen(tester);
    });
  });

  test('RfThreatLevel.fromDbm thresholds and keys', () {
    expect(RfThreatLevel.fromDbm(null), RfThreatLevel.quiet);
    expect(RfThreatLevel.fromDbm(-90), RfThreatLevel.quiet);
    expect(RfThreatLevel.fromDbm(-70), RfThreatLevel.quiet);
    expect(RfThreatLevel.fromDbm(-69), RfThreatLevel.moderate);
    expect(RfThreatLevel.fromDbm(-50), RfThreatLevel.moderate);
    expect(RfThreatLevel.fromDbm(-49), RfThreatLevel.strong);
    expect(RfThreatLevel.strong.labelKey, 'rf_level_strong');
    expect(RfThreatLevel.moderate.suggestionKey, 'rf_level_moderate_hint');
  });

  test('RfWavePainter repaints on new data only', () {
    final a = RfWavePainter(history: const [-80, -60], color: _red);
    expect(a.shouldRepaint(a), isFalse);
    expect(
      a.shouldRepaint(RfWavePainter(history: const [-80], color: _red)),
      isTrue,
    );
  });
}
