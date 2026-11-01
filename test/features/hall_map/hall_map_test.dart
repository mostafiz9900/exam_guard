// Hall map: what goes on the map, placing nodes (saved per room), the
// screen flow, and every state on a small phone in light/dark × en/bn/ar.
// Screenshots: MAP_SHOTS=<dir> flutter test <this file>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/hall_map/model/hall_locator.dart';
import 'package:exam_guard/features/hall_map/view/hall_map_screen.dart';
import 'package:exam_guard/features/hall_map/view_model/hall_map_view_model.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import '../node_setup/node_fakes.dart';

final _now = DateTime(2026, 11, 1, 10);

ScannedDeviceModel _d(
  String id,
  String name,
  int rssi, {
  String type = 'Smart Earpiece / Audio',
  DeviceTransport tx = DeviceTransport.ble,
}) => ScannedDeviceModel(
  id: id,
  name: name,
  deviceType: type,
  rssi: rssi,
  lastSeen: _now,
  firstSeen: _now,
  transport: tx,
);

const _a = HallMember(
  id: 'N-A',
  name: 'Pahara-Front',
  kind: HallMemberKind.node,
);
const _b = HallMember(
  id: 'N-B',
  name: 'Pahara-Back-left',
  kind: HallMemberKind.node,
);
const _c = HallMember(
  id: 'N-C',
  name: 'Pahara-Back-right',
  kind: HallMemberKind.node,
);

RemoteDevice _heard(HallMember by, ScannedDeviceModel d) => RemoteDevice(
  device: d,
  sourceId: by.id,
  sourceName: by.name,
  receivedAt: _now,
);

HallState _hall({
  List<HallMember> nodes = const [_a, _b, _c],
  List<RemoteDevice> heard = const [],
  List<RemoteAlert> alerts = const [],
  List<OfflineNode> offline = const [],
}) => HallState(
  selfId: 'P-ME',
  nodeKey: 'K',
  role: HallRole.host,
  status: HallLinkStatus.hosting,
  members: [
    const HallMember(id: 'P-ME', name: 'Me', kind: HallMemberKind.phone),
    ...nodes,
  ],
  remoteDevices: heard,
  remoteAlerts: alerts,
  offlineNodes: offline,
);

// 6 × 8 room; nodes front-left, back-left, back-right.
const _placed = {'N-A': (0, 0), 'N-B': (5, 0), 'N-C': (5, 7)};

/// An earpiece at D5 (3, 4) heard by all three nodes; a hotspot router
/// (room equipment), a trusted watch and the other nodes' own beacons.
final _busy = _hall(
  heard: [
    _heard(_a, _d('EAR', 'Mini Earbud', -67)),
    _heard(_b, _d('EAR', 'Mini Earbud', -66)),
    _heard(_c, _d('EAR', 'Mini Earbud', -66)),
    _heard(_b, _d('BAND', 'Mi Smart Band 8', -58, type: 'Wearable')),
    _heard(
      _a,
      _d(
        'wifi:AP',
        'Hall-Router',
        -50,
        type: 'Wi-Fi Access Point',
        tx: DeviceTransport.wifi,
      ),
    ),
    _heard(_c, _d('TRUSTED', 'Teacher Watch', -50, type: 'Wearable')),
    _heard(_a, _d('NB', 'Pahara-Back-left', -71, type: 'ESP32')),
    _heard(_b, _d('NA', 'Pahara-Front', -71, type: 'ESP32')),
  ],
  alerts: [
    RemoteAlert(
      alert: NewDeviceAlert(
        deviceId: 'EAR',
        displayName: 'Mini Earbud',
        deviceType: 'Smart Earpiece / Audio',
        transport: DeviceTransport.ble,
        rssi: -66,
        detectedAt: _now,
      ),
      sourceId: 'N-B',
      sourceName: _b.name,
    ),
  ],
);

class _Session extends SessionViewModel {
  _Session({this.rows, this.cols});

  final int? rows;
  final int? cols;

  @override
  SessionModel? build() => SessionModel(
    id: 's',
    instituteName: 'School',
    teacherName: 'Teacher',
    roomNumber: '302-B',
    startTime: _now,
    seatRows: rows,
    seatCols: cols,
  );

  @override
  Future<void> setSeatLayout({required int rows, required int cols}) async =>
      state = state!.copyWith(seatRows: rows, seatCols: cols);
}

void main() {
  group('what goes on the map', () {
    HallMapData build(HallState hall, {Map<String, (int, int)> at = _placed}) =>
        buildHallMap(
          rows: 6,
          cols: 8,
          hall: hall,
          placements: at,
          trusted: const {'TRUSTED'},
        );

    test('suspicious devices only, alerts first, located by the nodes', () {
      final map = build(_busy);
      expect(map.devices.map((d) => d.device.id), ['EAR', 'BAND']);
      final ear = map.devices.first;
      expect(ear.isAlert, isTrue);
      expect(ear.readings, hasLength(3));
      expect(ear.result.confidence, isNot(LocatorConfidence.low));
      // Room equipment, trusted devices and Pahara nodes are left out.
      expect(
        map.devices.map((d) => d.device.name),
        isNot(contains('Hall-Router')),
      );
    });

    test('nodes hearing each other calibrate the room', () {
      final map = build(_busy);
      expect(map.isCalibrated, isTrue);
      expect(
        map.pathLoss,
        inInclusiveRange(HallLocator.minPathLoss, HallLocator.maxPathLoss),
      );
      final none = build(_hall(heard: [_heard(_a, _d('EAR', 'x', -60))]));
      expect(none.isCalibrated, isFalse);
    });

    test('unplaced nodes and seats outside the layout locate nothing', () {
      final map = build(_busy, at: {'N-A': (0, 0), 'N-B': (40, 0)});
      expect(map.placedLive, 1);
      expect(map.hasUnplaced, isTrue);
      final ear = map.devices.firstWhere((d) => d.device.id == 'EAR');
      expect(ear.readings, hasLength(1), reason: 'only the placed node counts');
      expect(ear.result.confidence, LocatorConfidence.low);
    });

    test('offline nodes stay on the map but hear nothing', () {
      final map = build(
        _hall(
          nodes: const [_a],
          offline: [OfflineNode(member: _b, since: _now)],
          heard: [_heard(_a, _d('EAR', 'x', -60))],
        ),
      );
      expect(map.nodes.map((n) => (n.member.id, n.isLive)), [
        ('N-A', true),
        ('N-B', false),
      ]);
      expect(map.nodes.last.seat, (5, 0));
    });

    test('no seat layout: nodes listed, no devices', () {
      final map = buildHallMap(
        rows: 0,
        cols: 0,
        hall: _busy,
        placements: _placed,
      );
      expect(map.hasLayout, isFalse);
      expect(map.devices, isEmpty);
    });
  });

  group('placing nodes', () {
    late FakeStorage storage;
    late ProviderContainer c;

    setUp(() {
      storage = FakeStorage();
      c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          sessionViewModelProvider.overrideWith(
            () => _Session(rows: 6, cols: 8),
          ),
          hallViewModelProvider.overrideWith(() => FakeHall(_busy)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(hallMapViewModelProvider, (_, _) {});
    });

    test('saved per room; one node per seat', () async {
      final vm = c.read(hallMapViewModelProvider.notifier);
      await vm.place('N-A', 0, 0);
      await vm.place('N-B', 0, 0); // takes the seat, N-A moves off
      expect(c.read(hallMapViewModelProvider), {'N-B': (0, 0)});
      expect(storage.keys.single, 'hall_map_nodes_302b');

      // Same room next exam: still placed.
      final c2 = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          sessionViewModelProvider.overrideWith(
            () => _Session(rows: 6, cols: 8),
          ),
        ],
      );
      addTearDown(c2.dispose);
      expect(c2.read(hallMapViewModelProvider), {'N-B': (0, 0)});

      await vm.remove('N-B');
      expect(c.read(hallMapViewModelProvider), isEmpty);
    });

    test('seat layout form validates', () async {
      final vm = c.read(hallMapViewModelProvider.notifier);
      expect(await vm.setSeatLayout('', '5'), 'setup_seat_err_both');
      expect(await vm.setSeatLayout('0', '5'), 'setup_seat_err_range');
      expect(await vm.setSeatLayout('6', '8'), isNull);
    });
  });

  group('screen', () {
    final shotDir = Platform.environment['MAP_SHOTS'];
    final boundary = GlobalKey();

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await loadFonts();
    });

    Future<(FakeStorage, List<Object?>)> pump(
      WidgetTester tester, {
      HallState? hall,
      int? rows = 6,
      int? cols = 8,
      Map<String, (int, int)> placed = _placed,
      ThemeMode mode = ThemeMode.light,
      Locale locale = const Locale('en'),
    }) async {
      final storage = FakeStorage();
      if (placed.isNotEmpty) {
        await storage.write(
          'hall_map_nodes_302b',
          '{${placed.entries.map((e) => '"${e.key}":[${e.value.$1},${e.value.$2}]').join(',')}}',
        );
      }
      final pushed = <Object?>[];
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HallMapScreen()),
          GoRoute(
            path: '/action/new',
            builder: (_, state) {
              pushed.add(state.extra);
              return const Scaffold(body: Text('incident form'));
            },
          ),
          GoRoute(
            path: '/radar',
            builder: (_, state) {
              pushed.add(state.extra);
              return const Scaffold(body: Text('radar'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      rootBundle.clear();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          startLocale: locale,
          saveLocale: false,
          child: ProviderScope(
            overrides: [
              localStorageProvider.overrideWithValue(storage),
              sessionViewModelProvider.overrideWith(
                () => _Session(rows: rows, cols: cols),
              ),
              hallViewModelProvider.overrideWith(() => FakeHall(hall ?? _busy)),
            ],
            child: Builder(
              builder: (context) => AppScreenSize(
                builder: (_) => MaterialApp.router(
                  routerConfig: router,
                  // Around the navigator so sheets are in screenshots.
                  builder: (_, child) =>
                      RepaintBoundary(key: boundary, child: child),
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: mode,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                ),
              ),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.byType(HallMapScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      return (storage, pushed);
    }

    Future<void> shot(WidgetTester tester, String name) async {
      final dir = shotDir;
      if (dir == null) return;
      await tester.runAsync(() async {
        final b =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    testWidgets('device on the map → sheet → log incident at its seat', (
      tester,
    ) async {
      final (_, pushed) = await pump(tester);
      expect(find.text('Devices located (2)'), findsNothing); // below fold
      expect(find.byKey(const Key('hall_map_dot_EAR')), findsOneWidget);
      expect(find.byKey(const Key('hall_map_node_marker_N-A')), findsOneWidget);
      expect(find.byKey(const Key('hall_map_calibration')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hall_map_dot_EAR')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Most likely near'), findsOneWidget);
      expect(find.text('Pahara-Back-left'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hall_map_log')));
      await tester.pumpAndSettle();
      final args = pushed.single! as ActionEntryArgs;
      expect(args.device!.id, 'EAR');
      expect(args.seat, isNotNull);
      expect(args.notes, contains('Hall map'));
    });

    testWidgets('placing: pick a node, tap a seat', (tester) async {
      final (storage, _) = await pump(tester, placed: const {});
      expect(find.byKey(const Key('hall_map_place_prompt')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hall_map_place_start')));
      await tester.pump();
      expect(find.byKey(const Key('hall_map_placing')), findsOneWidget);

      // First unplaced node is preselected; tap seat A1 (top-left cell).
      final grid = tester.getTopLeft(find.byKey(const Key('hall_map_grid')));
      await tester.tapAt(grid + const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hall_map_node_marker_N-A')), findsOneWidget);
      expect(storage.values['hall_map_nodes_302b'], contains('"N-A":[0,0]'));
    });

    testWidgets('no seat layout: form first, then the map', (tester) async {
      await pump(tester, rows: null, cols: null);
      expect(find.byKey(const Key('hall_map_layout_form')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('hall_map_rows')), '0');
      await tester.enterText(find.byKey(const Key('hall_map_cols')), '8');
      await tester.tap(find.byKey(const Key('hall_map_layout_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1'), findsWidgets);
      expect(find.byKey(const Key('hall_map_layout_form')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('hall_map_rows')), '6');
      await tester.tap(find.byKey(const Key('hall_map_layout_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hall_map_layout_form')), findsNothing);
      expect(find.byKey(const Key('hall_map_grid')), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        final tag = '${locale.languageCode}_${mode.name}';
        testWidgets('map $tag renders', (tester) async {
          await pump(tester, mode: mode, locale: locale);
          expect(tester.takeException(), isNull);
          await shot(tester, 'map_$tag');
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await shot(tester, 'map_${tag}_end');
          await tester.tap(find.byKey(const Key('hall_map_device_EAR')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await shot(tester, 'map_${tag}_sheet');
        });
      }
    }
  });
}
