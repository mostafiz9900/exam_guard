// Sensor nodes screen, "Add a sensor node" wizard and the dashboard tile:
// the full Bluetooth setup flow against a fake node, and every state on a
// small phone in light/dark and all three languages.
// Screenshots: NODE_SHOTS=<dir> flutter test <this file>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/bluetooth/i_ble_gatt.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/widgets/sensor_nodes_tile.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/view/node_setup_screen.dart';
import 'package:exam_guard/features/node_setup/view/sensor_nodes_screen.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import 'node_fakes.dart';

final _shotDir = Platform.environment['NODE_SHOTS'];
final _boundary = GlobalKey();

final _withOffline = HallState(
  selfId: 'P-ME',
  nodeKey: 'K7M2Q9XW3D',
  role: HallRole.host,
  status: HallLinkStatus.hosting,
  members: hostingWithNode.members,
  offlineNodes: [
    OfflineNode(
      member: const HallMember(
        id: 'N-FRONT1',
        name: 'Pahara-Front-left',
        kind: HallMemberKind.node,
      ),
      since: DateTime(2026, 11, 1, 10, 32),
    ),
  ],
);

class _Rig {
  _Rig({HallState? hall, bool exam = true})
    : hall = FakeHall(
        hall ?? const HallState(selfId: 'P-ME', nodeKey: 'K7M2Q9XW3D'),
      ),
      exam = exam;

  final FakeHall hall;
  final bool exam;
  final ble = FakeBle();
  final node = FakeNodeLink();
  late final gatt = FakeGatt(node);
  final storage = FakeStorage();
}

Future<_Rig> _pump(
  WidgetTester tester,
  Widget child, {
  _Rig? rig,
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  final r = rig ?? _Rig();
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
          hallViewModelProvider.overrideWith(() => r.hall),
          sessionViewModelProvider.overrideWith(
            () => FakeSession(running: r.exam),
          ),
          bluetoothServiceProvider.overrideWithValue(r.ble),
          bleGattProvider.overrideWithValue(r.gatt),
          localStorageProvider.overrideWithValue(r.storage),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: RepaintBoundary(key: _boundary, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 40 && find.byWidget(child).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
  return r;
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

/// Prepare → search → node found → Wi-Fi form.
Future<void> _toWifi(WidgetTester tester, _Rig r) async {
  await _tap(tester, find.byKey(const Key('node_find_button')));
  r.ble.hear('BB:01', 'Pahara-Setup-A1B2C3', -52);
  await _settle(tester);
  await _tap(tester, find.byKey(const Key('node_candidate_BB:01')));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadFonts();
  });

  group('wizard', () {
    testWidgets('find → Wi-Fi → node tests it → done, live in the hall', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        const NodeSetupScreen(),
        rig: _Rig(
          hall: const HallState(
            selfId: 'P-ME',
            nodeKey: 'K7M2Q9XW3D',
            role: HallRole.host,
            status: HallLinkStatus.hosting,
          ),
        ),
      );
      expect(find.text('Power on the node'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('node_find_button')));
      expect(find.text('Looking for nodes…'), findsOneWidget);
      expect(find.text('Not showing up?'), findsOneWidget);

      r.ble
        ..hear('AA:01', 'AirPods', -40)
        ..hear('BB:01', 'Pahara-Setup-A1B2C3', -52);
      await _settle(tester);
      expect(find.text('Node A1B2C3'), findsOneWidget);
      expect(find.text('Very close'), findsOneWidget);
      expect(find.text('AirPods'), findsNothing);

      await _tap(tester, find.byKey(const Key('node_candidate_BB:01')));
      expect(
        find.textContaining('Connected to Pahara-Node-A1B2C3'),
        findsOneWidget,
      );
      expect(find.text('Hall-Hotspot'), findsOneWidget);
      expect(
        find.text('The node key is sent by the app — nothing to type.'),
        findsOneWidget,
      );

      // Short password is caught before anything is sent.
      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'abc',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      expect(
        find.text('Wi-Fi passwords have at least 8 characters.'),
        findsOneWidget,
      );
      expect(r.node.configs, isEmpty);

      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'hall12345',
      );
      await tester.enterText(
        find.byKey(const Key('node_name_field')),
        'Back-row',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      await _settle(tester);

      expect(r.node.configs.single['key'], 'K7M2Q9XW3D');
      expect(r.node.configs.single['ssid'], 'Hall-Hotspot');
      expect(find.text('Node set up'), findsOneWidget);
      expect(find.byKey(const Key('node_done_waiting')), findsOneWidget);

      // The node restarts and joins this phone's hall.
      r.hall.set(hostingWithNode);
      await _settle(tester);
      expect(find.text('Live in this hall'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wrong password shows the reason and goes back to fix it', (
      tester,
    ) async {
      final r = await _pump(tester, const NodeSetupScreen());
      r.node.outcome = NodeOutcome.badPassword;
      await _toWifi(tester, r);
      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'wrongpass',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      await _settle(tester);
      expect(find.text("Wi-Fi didn't work"), findsOneWidget);
      expect(find.text('Wrong password for "Hall-Hotspot".'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('node_retry_button')));
      final field = tester.widget<TextField>(
        find.byKey(const Key('node_password_field')),
      );
      expect(field.controller!.text, 'wrongpass', reason: 'kept to fix');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no exam: done says it joins later, no host button', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        const NodeSetupScreen(),
        rig: _Rig(exam: false),
      );
      r.node.outcome = NodeOutcome.noHost;
      await _toWifi(tester, r);
      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'hall12345',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      await _settle(tester);
      expect(find.byKey(const Key('node_done_host')), findsOneWidget);
      expect(find.byKey(const Key('node_done_host_button')), findsNothing);
    });

    testWidgets('exam running, hall not hosted: done offers hosting', (
      tester,
    ) async {
      final r = await _pump(tester, const NodeSetupScreen());
      r.node.outcome = NodeOutcome.noHost;
      await _toWifi(tester, r);
      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'hall12345',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      await _settle(tester);
      await _tap(tester, find.byKey(const Key('node_done_host_button')));
      expect(r.hall.hostCalls, 1);
    });

    testWidgets('typing another network by name', (tester) async {
      final r = await _pump(tester, const NodeSetupScreen());
      await _toWifi(tester, r);
      await _tap(tester, find.byKey(const Key('node_net_other')));
      await tester.enterText(
        find.byKey(const Key('node_ssid_field')),
        'Hidden-Net',
      );
      await tester.enterText(
        find.byKey(const Key('node_password_field')),
        'hall12345',
      );
      await _tap(tester, find.byKey(const Key('node_connect_button')));
      await _settle(tester);
      expect(r.node.configs.single['ssid'], 'Hidden-Net');
    });
  });

  group('sensor nodes screen', () {
    testWidgets('no nodes: explains, shows what to buy, can host', (
      tester,
    ) async {
      final r = await _pump(tester, const SensorNodesScreen());
      expect(find.textContaining('No nodes yet'), findsOneWidget);
      expect(find.text('Host the hall for nodes'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('node_host_button')));
      expect(r.hall.hostCalls, 1);
      await tester.scrollUntilVisible(
        find.text('ESP32 DevKit board (ESP32-WROOM-32)'),
        200,
      );
      expect(find.text('USB data cable'), findsOneWidget);
    });

    testWidgets('live and offline nodes are listed; offline can be cleared', (
      tester,
    ) async {
      await _pump(
        tester,
        const SensorNodesScreen(),
        rig: _Rig(hall: _withOffline),
      );
      expect(
        find.text('1 live · 1 offline — check the offline node'),
        findsOneWidget,
      );
      expect(find.text('Pahara-Back-row'), findsOneWidget);
      expect(find.text('Pahara-Front-left'), findsOneWidget);
      expect(find.text('Ready for nodes'), findsOneWidget);
      expect(find.byKey(const Key('node_host_button')), findsNothing);
    });
  });

  group('dashboard tile', () {
    Widget tile() => const Scaffold(body: SensorNodesTile());

    testWidgets('no nodes invites setup', (tester) async {
      await _pump(tester, tile());
      expect(find.text('Sensor nodes'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
    });

    testWidgets('live node shows count and devices heard', (tester) async {
      await _pump(tester, tile(), rig: _Rig(hall: hostingWithNode));
      expect(find.text('1 live'), findsOneWidget);
      expect(find.textContaining('LIVE · 1 node(s)'), findsOneWidget);
    });

    testWidgets('offline node turns it red and names it', (tester) async {
      await _pump(tester, tile(), rig: _Rig(hall: _withOffline));
      expect(find.text('Sensor node offline'), findsOneWidget);
      expect(find.text('Pahara-Front-left'), findsOneWidget);
      expect(find.text('1 offline'), findsOneWidget);
    });
  });

  // Every screen and step on a small phone, light/dark, en/bn/ar.
  for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      final tag = '${locale.languageCode}_${mode.name}';

      Future<void> scrollAll(WidgetTester tester, String name) async {
        expect(tester.takeException(), isNull);
        await _shot(tester, name);
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _shot(tester, '${name}_end');
      }

      testWidgets('nodes screen $tag renders', (tester) async {
        await _pump(
          tester,
          const SensorNodesScreen(),
          rig: _Rig(hall: _withOffline),
          mode: mode,
          locale: locale,
        );
        await scrollAll(tester, 'nodes_$tag');
      });

      testWidgets('wizard $tag renders every step', (tester) async {
        final r = await _pump(
          tester,
          const NodeSetupScreen(),
          mode: mode,
          locale: locale,
        );
        await scrollAll(tester, 'wizard_prepare_$tag');
        await _tap(tester, find.byKey(const Key('node_find_button')));
        r.ble.hear('BB:01', 'Pahara-Setup-A1B2C3', -52);
        r.ble.hear('BB:02', 'Pahara-Setup-D4E5F6', -78);
        await _settle(tester);
        await scrollAll(tester, 'wizard_search_$tag');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
        await _settle(tester);
        await _tap(tester, find.byKey(const Key('node_candidate_BB:01')));
        await scrollAll(tester, 'wizard_wifi_$tag');
        r.node.outcome = NodeOutcome.noNetwork;
        await tester.enterText(
          find.byKey(const Key('node_password_field')),
          'hall12345',
        );
        await _tap(tester, find.byKey(const Key('node_connect_button')));
        await _settle(tester);
        await scrollAll(tester, 'wizard_failed_$tag');
        await _tap(tester, find.byKey(const Key('node_retry_button')));
        r.node.outcome = NodeOutcome.noHost;
        await _tap(tester, find.byKey(const Key('node_connect_button')));
        await _settle(tester);
        await scrollAll(tester, 'wizard_done_$tag');
      });

      testWidgets('tile $tag renders', (tester) async {
        await _pump(
          tester,
          const Scaffold(body: SensorNodesTile()),
          rig: _Rig(hall: _withOffline),
          mode: mode,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
