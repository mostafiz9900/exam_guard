// Hall screen and dashboard tile: every state renders without overflow on
// a small phone, light and dark, in all three languages.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/dashboard/view/widgets/hall_link_tile.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view/hall_screen.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;

class _FixedHall extends HallViewModel {
  _FixedHall(this.fixed);

  final HallState fixed;

  @override
  HallState build() => fixed;
}

final _now = DateTime(2026, 10, 25, 10, 15);

ScannedDeviceModel _d(String id, String name, String type, int rssi) =>
    ScannedDeviceModel(
      id: id,
      name: name,
      deviceType: type,
      rssi: rssi,
      lastSeen: _now,
      firstSeen: _now,
    );

const _idle = HallState(selfId: 'P-ME', nodeKey: 'K7M2Q9XW3D');

final _hosting = HallState(
  selfId: 'P-ME',
  nodeKey: 'K7M2Q9XW3D',
  role: HallRole.host,
  status: HallLinkStatus.hosting,
  room: '302-B',
  invite: const HallInvite(
    host: '192.168.43.1',
    port: 47800,
    token: 'ABCD2345',
    room: '302-B',
  ),
  members: const [
    HallMember(
      id: 'P-ME',
      name: 'Md. Abdur Rahman Chowdhury',
      kind: HallMemberKind.phone,
      isHost: true,
    ),
    HallMember(id: 'P-2', name: 'Farzana', kind: HallMemberKind.phone),
    HallMember(
      id: 'N-1',
      name: 'ExamGuard-Node-Back-Row',
      kind: HallMemberKind.node,
    ),
  ],
  remoteDevices: [
    RemoteDevice(
      device: _d('AA:01', 'soundcore R50i', 'Smart Earpiece / Audio', -52),
      sourceId: 'N-1',
      sourceName: 'ExamGuard-Node-Back-Row',
      receivedAt: _now,
    ),
    RemoteDevice(
      device: _d('AA:02', '', ScannedDeviceModel.appleHiddenType, -71),
      sourceId: 'P-2',
      sourceName: 'Farzana',
      receivedAt: _now,
    ),
  ],
  offlineNodes: [
    OfflineNode(
      member: const HallMember(
        id: 'N-2',
        name: 'ExamGuard-Node-Front',
        kind: HallMemberKind.node,
      ),
      since: _now,
    ),
  ],
  remoteAlerts: [
    RemoteAlert(
      alert: NewDeviceAlert(
        deviceId: 'AA:01',
        displayName: 'soundcore R50i',
        deviceType: 'Smart Earpiece / Audio',
        transport: DeviceTransport.ble,
        rssi: -52,
        detectedAt: _now,
      ),
      sourceId: 'N-1',
      sourceName: 'ExamGuard-Node-Back-Row',
    ),
  ],
);

const _reconnecting = HallState(
  selfId: 'P-ME',
  nodeKey: 'K7M2Q9XW3D',
  role: HallRole.member,
  status: HallLinkStatus.reconnecting,
  room: '302-B',
  errorKey: 'hall_err_unreachable',
);

final _shotDir = Platform.environment['HALL_SHOTS'];
final _boundary = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  HallState state,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
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
          hallViewModelProvider.overrideWith(() => _FixedHall(state)),
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadFonts();
  });

  final states = {
    'idle': _idle,
    'hosting': _hosting,
    'reconnecting': _reconnecting,
  };
  for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final e in states.entries) {
        final name = 'hall_${e.key}_${locale.languageCode}_${mode.name}';
        testWidgets('$name renders without overflow', (tester) async {
          await _pump(
            tester,
            e.value,
            const HallScreen(),
            mode: mode,
            locale: locale,
          );
          expect(tester.takeException(), isNull);
          await _shot(tester, name);
          await tester.drag(find.byType(ListView), const Offset(0, -480));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _shot(tester, '${name}_mid');
          // Scroll through everything (lists build lazily).
          await tester.drag(find.byType(ListView), const Offset(0, -3000));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _shot(tester, '${name}_end');
        });
      }
    }
  }

  testWidgets('hosting shows QR, code, members, shared devices, alerts', (
    tester,
  ) async {
    await _pump(tester, _hosting, const HallScreen());
    expect(find.text('Code: ABCD2345'), findsOneWidget);
    expect(find.text('LIVE — hosting room 302-B'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.textContaining('ExamGuard-Node-Back-Row'), findsWidgets);
  });

  testWidgets('idle offers host and join, never claims to be live', (
    tester,
  ) async {
    await _pump(tester, _idle, const HallScreen());
    expect(find.text('Host this hall'), findsOneWidget);
    expect(find.text('Join a hall'), findsOneWidget);
    expect(find.textContaining('LIVE'), findsNothing);
  });

  group('dashboard tile', () {
    Widget tile() => const Scaffold(body: HallLinkTile());

    testWidgets('pending alert wins and names who detected it', (tester) async {
      await _pump(tester, _hosting, tile());
      expect(find.text('1 alert(s) from other invigilators'), findsOneWidget);
      expect(
        find.textContaining('ExamGuard-Node-Back-Row detected'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('link lost is shown as not live', (tester) async {
      await _pump(tester, _reconnecting, tile());
      expect(find.text('Link lost — hall data is NOT live'), findsOneWidget);
    });

    testWidgets('not linked invites to link', (tester) async {
      await _pump(tester, _idle, tile());
      expect(
        find.text('Not linked — tap to share with other invigilators'),
        findsOneWidget,
      );
    });
  });
}
