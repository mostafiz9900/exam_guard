// Report summary screen: empty and busy sessions, metrics, severity styles,
// seat heat map, photo viewer, PDF export/share (faked), navigation and the
// report view model's exporting / error states. Small phone, light and dark.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/pdf/i_pdf_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/history/view/history_screen.dart';
import 'package:exam_guard/features/history/view/widgets/history_entry_card.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/report/view/report_summary_screen.dart';
import 'package:exam_guard/features/report/view/widgets/incident_log_card.dart';
import 'package:exam_guard/features/report/view/widgets/metric_card.dart';
import 'package:exam_guard/features/report/view/widgets/seat_heat_map.dart';
import 'package:exam_guard/features/report/view/widgets/severity_style.dart';
import 'package:exam_guard/features/report/view_model/report_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/activity_sample.dart';
import 'package:exam_guard/features/session/model/incident_evidence.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Saves [s] like SessionRepository does (pointer keys included).
  void put(SessionModel s) {
    values['session_${s.id}'] = s.toJson();
    values['last_session_id'] = s.id;
    if (s.isActive) values['current_session_id'] = s.id;
  }
}

class _FakePdf implements IPdfService {
  int calls = 0;
  bool fail = false;

  @override
  Future<Uint8List> buildTableDocument(PdfTableDocument document) async {
    calls++;
    if (fail) throw StateError('pdf boom');
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

class _ShareCall {
  _ShareCall(this.fileName, this.mimeType, this.subject, this.origin);
  final String fileName;
  final String mimeType;
  final String? subject;
  final Rect? origin;
}

class _FakeShare implements IShareService {
  final calls = <_ShareCall>[];
  ShareOutcome outcome = ShareOutcome.shared;
  Object? error;
  Completer<ShareOutcome>? pending;

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  }) async {
    calls.add(_ShareCall(fileName, mimeType, subject, origin));
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return outcome;
  }

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async => outcome;
}

final _start = DateTime(2026, 10, 13, 9);

ActionLogModel _log(
  String name,
  LogSeverity severity, {
  String? seat,
  int minute = 0,
  List<String> photos = const [],
  String notes = '',
}) => ActionLogModel(
  deviceName: name,
  deviceId: 'AA:BB:$minute',
  category: 'Phone',
  severity: severity,
  location: 'Desk',
  notes: notes,
  createdAt: _start.add(Duration(minutes: minute)),
  seat: seat,
  photoPaths: photos,
);

/// 7 incidents: 2 critical, 2 high, 2 medium, 1 low. Seats A1 (critical +
/// low → 2), B2 (high), C4 (medium), Z9 (outside a 3×4 layout), two without
/// a seat.
List<ActionLogModel> _manyLogs() => [
  _log('Phone-0', LogSeverity.critical, seat: 'A1', minute: 1),
  _log('Earbud-1', LogSeverity.high, seat: 'B2', minute: 2),
  _log('Watch-2', LogSeverity.medium, seat: 'C4', minute: 3),
  _log('Tag-3', LogSeverity.low, seat: 'A1', minute: 4),
  _log('Phone-4', LogSeverity.critical, minute: 5, notes: 'In pocket'),
  _log('Earbud-5', LogSeverity.high, seat: 'Z9', minute: 6),
  _log(
    'Cam-6',
    LogSeverity.medium,
    minute: 7,
    photos: const ['/nope/a.jpg', '/nope/b.jpg'],
  ),
];

SessionModel _session({
  String id = '1',
  String institute = 'Dhaka College',
  String room = '12/B',
  bool ended = true,
  List<ActionLogModel> logs = const [],
  int? rows,
  int? cols,
  DateTime? start,
}) {
  final s = start ?? _start;
  return SessionModel(
    id: id,
    instituteName: institute,
    teacherName: 'Rahim Uddin',
    roomNumber: room,
    startTime: s,
    endTime: ended ? s.add(const Duration(hours: 3)) : null,
    deviceLogs: logs,
    seatRows: rows,
    seatCols: cols,
  );
}

class _Harness {
  _Harness(this.container, this.pdf, this.share);
  final ProviderContainer container;
  final _FakePdf pdf;
  final _FakeShare share;
}

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

/// Pumps the app at [initial] ('/report' or '/history') with [storage].
/// When [show] is given, it is made the session in memory first (the
/// just-ended / viewed session).
Future<_Harness> _pump(
  WidgetTester tester, {
  _MemoryStorage? storage,
  SessionModel? show,
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
  String initial = AppRoute.report,
  Size size = const Size(320, 568),
}) async {
  rootBundle.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = storage ?? _MemoryStorage();
  if (show != null) store.put(show);
  final pdf = _FakePdf();
  final share = _FakeShare();
  final container = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(store),
      pdfServiceProvider.overrideWithValue(pdf),
      shareServiceProvider.overrideWithValue(share),
    ],
  );
  addTearDown(container.dispose);
  if (show != null) {
    container.read(sessionViewModelProvider.notifier).openSession(show.id);
  }

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoute.sessionSetup,
        builder: (_, _) => _stub('SETUP SCREEN'),
      ),
      GoRoute(
        path: AppRoute.actionNew,
        builder: (_, _) => _stub('ACTION NEW SCREEN'),
      ),
      GoRoute(
        path: AppRoute.report,
        builder: (_, _) => const ReportSummaryScreen(),
      ),
      GoRoute(path: AppRoute.history, builder: (_, _) => const HistoryScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: UncontrolledProviderScope(
        container: container,
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
  final target = initial == AppRoute.history
      ? find.byType(HistoryScreen)
      : find.byType(ReportSummaryScreen);
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
  expect(target, findsOneWidget);
  return _Harness(container, pdf, share);
}

String _metric(WidgetTester tester, String title) => tester
    .widgetList<MetricCard>(find.byType(MetricCard))
    .firstWhere((m) => m.title == title)
    .count;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ReportSummaryScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Future<void> _tapExport(WidgetTester tester) async {
  final button = find.widgetWithText(
    PrimaryButton,
    'Export & Share PDF Report',
  );
  await _scrollTo(tester, button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
}

/// Real font metrics (the default test font draws every glyph 1 em wide,
/// which overstates text width). Bangla glyphs come from the bundled Noto
/// font registered in the same family.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async =>
      ByteData.view(File(path).readAsBytesSync().buffer);

  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(bytes('$dir/Roboto-$f.ttf'));
  }
  roboto
    ..addFont(bytes('assets/fonts/NotoSansBengali-Regular.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-Bold.ttf'));
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(bytes('$dir/MaterialIcons-Regular.otf'))).load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  group('severity style', () {
    test(
      'each severity has a distinct color; critical uses the error color',
      () {
        final colors = LogSeverity.values.map(reportSeverityColor).toSet();
        expect(colors, hasLength(LogSeverity.values.length));
        expect(reportSeverityColor(LogSeverity.critical), AppColors.error);
      },
    );
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('zero incidents shows the empty state ($mode)', (tester) async {
      await _pump(tester, show: _session(), mode: mode);

      expect(find.text('Dhaka College'), findsOneWidget);
      expect(find.text('12/B'), findsOneWidget);
      expect(find.text('NO MAJOR VIOLATIONS'), findsOneWidget);
      expect(find.text('Incident Audit Logs (0)'), findsOneWidget);
      expect(_metric(tester, 'Critical Violations'), '0');
      expect(_metric(tester, 'High Threats'), '0');
      expect(_metric(tester, 'Total Logged'), '0');
      expect(find.byType(IncidentLogCard), findsNothing);
      expect(find.byType(SeatHeatMap), findsNothing);
      await _scrollTo(tester, find.text('No Incidents Logged'));
      expect(find.text('No Incidents Logged'), findsOneWidget);
      expect(find.text('No baseline was taken'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('many incidents: metrics, order, severity chips ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        show: _session(logs: _manyLogs(), rows: 3, cols: 4),
        mode: mode,
      );

      expect(find.text('VIOLATIONS FOUND'), findsOneWidget);
      expect(_metric(tester, 'Critical Violations'), '2');
      expect(_metric(tester, 'High Threats'), '2');
      expect(_metric(tester, 'Total Logged'), '7');
      expect(find.text('Incident Audit Logs (7)'), findsOneWidget);

      final cards = tester
          .widgetList<IncidentLogCard>(find.byType(IncidentLogCard))
          .map((c) => c.log.deviceName)
          .toList();
      expect(cards, [
        'Phone-0',
        'Earbud-1',
        'Watch-2',
        'Tag-3',
        'Phone-4',
        'Earbud-5',
        'Cam-6',
      ]);
      // Rendered top to bottom in that order.
      final ys = [for (final n in cards) tester.getTopLeft(find.text(n)).dy];
      expect(ys, orderedEquals([...ys]..sort()));

      // Severity chip text is colored with the severity color.
      for (final sev in LogSeverity.values) {
        final chip = find.descendant(
          of: find.byType(IncidentLogCard),
          matching: find.text(reportSeverityLabel(sev)),
        );
        expect(chip, findsWidgets);
        expect(
          tester.widget<Text>(chip.first).style?.color,
          reportSeverityColor(sev),
        );
      }
      expect(find.text('Note: In pocket'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('evidence chart on the incident and exam activity chart', (
    tester,
  ) async {
    final withEvidence = ActionLogModel(
      deviceName: 'TWS Earbud',
      deviceId: 'AA:01',
      category: 'Bluetooth Device',
      severity: LogSeverity.high,
      location: 'Desk',
      notes: '',
      createdAt: _start.add(const Duration(minutes: 10)),
      evidence: IncidentEvidence(
        trace: [
          for (var s = 0; s < 120; s += 5)
            EvidencePoint(_start.add(Duration(minutes: 8, seconds: s)), -62),
        ],
        spans: [
          EvidenceSpan(
            _start.add(const Duration(minutes: 8)),
            _start.add(const Duration(minutes: 10)),
          ),
        ],
        firstSeen: _start.add(const Duration(minutes: 8)),
        peakRssi: -58,
        reappearances: 2,
        timePresent: const Duration(minutes: 2),
      ),
    );
    final session = _session(logs: [withEvidence]).copyWith(
      activity: [
        for (var m = 0; m < 30; m += 5)
          ActivitySample(
            at: _start.add(Duration(minutes: m)),
            devices: 3 + m ~/ 5,
            untrusted: m ~/ 10,
            alerts: 0,
          ),
      ],
    );
    await _pump(tester, show: session);
    expect(find.byKey(const Key('report_activity_chart')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('report_incident_evidence')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('-58 dBm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('heat map shows counts per seat and opens a seat\'s incidents', (
    tester,
  ) async {
    await _pump(tester, show: _session(logs: _manyLogs(), rows: 3, cols: 4));

    final map = find.byType(SeatHeatMap);
    expect(map, findsOneWidget);
    expect(find.text('Seat map'), findsOneWidget);
    // 3×4 cells, each with a seat id tooltip.
    expect(
      find.descendant(of: map, matching: find.byType(Tooltip)),
      findsNWidgets(12),
    );
    Finder cellText(String seat) => find.descendant(
      of: find.descendant(of: map, matching: find.byTooltip(seat)),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(cellText('A1')).data, '2');
    expect(tester.widget<Text>(cellText('B2')).data, '1');
    expect(tester.widget<Text>(cellText('C4')).data, '1');
    expect(tester.widget<Text>(cellText('A2')).data, '');

    // A1's color is its highest severity (critical).
    final a1 = tester.widget<Material>(
      find.descendant(
        of: find.descendant(of: map, matching: find.byTooltip('A1')),
        matching: find.byType(Material),
      ),
    );
    expect(
      a1.color,
      reportSeverityColor(LogSeverity.critical).withValues(alpha: 0.85),
    );

    await _scrollTo(tester, cellText('A1'));
    await tester.tap(cellText('A1'));
    await tester.pumpAndSettle();
    expect(find.text('Seat A1 · 2 incidents'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.byType(IncidentLogCard)),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no seat layout hides the heat map', (tester) async {
    await _pump(tester, show: _session(logs: _manyLogs()));
    expect(find.byType(SeatHeatMap), findsNothing);
    expect(find.text('Seat map'), findsNothing);
    // Incidents still list their seat.
    expect(find.text('Seat A1'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  test('report view model: seat summaries and incidents at a seat', () {
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(_MemoryStorage())],
    );
    addTearDown(container.dispose);
    final sub = container.listen(reportViewModelProvider, (_, _) {});
    addTearDown(sub.close);
    final vm = container.read(reportViewModelProvider.notifier);
    final s = _session(logs: _manyLogs(), rows: 3, cols: 4);
    final summaries = vm.seatSummaries(s);
    expect(summaries.keys.toSet(), {'A1', 'B2', 'C4', 'Z9'});
    expect(summaries['A1']!.count, 2);
    expect(summaries['A1']!.highestSeverity, LogSeverity.critical);
    expect(vm.incidentsAtSeat(s, 'a1').map((l) => l.deviceName), [
      'Phone-0',
      'Tag-3',
    ]);
    expect(vm.incidentsAtSeat(s, 'D1'), isEmpty);
    expect(container.read(reportViewModelProvider).isExporting, isFalse);
    expect(container.read(reportViewModelProvider).messageKey, isNull);
  });

  for (final locale in [const Locale('en'), const Locale('bn')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('long institute name does not overflow ($locale, $mode)', (
        tester,
      ) async {
        await _pump(
          tester,
          locale: locale,
          mode: mode,
          show: _session(
            institute:
                'ঢাকা রেসিডেনশিয়াল মডেল কলেজ — প্রধান পরীক্ষা হল ও '
                'Dhaka Residential Model College Main Examination Hall',
            room: 'কক্ষ ৩০২-বি / Room 302-B with a very long name',
            logs: [
              ..._manyLogs(),
              _log(
                'একটি খুব দীর্ঘ নামের ব্লুটুথ হেডফোন ডিভাইস ' * 2,
                LogSeverity.high,
                seat: 'B3',
                minute: 9,
                notes: 'দীর্ঘ নোট যা মোড়ানো উচিত। ' * 6,
              ),
            ],
            rows: 6,
            cols: 10,
          ),
        );
        if (locale.languageCode == 'bn') {
          expect(find.text('Export & Share PDF Report'), findsNothing);
        }
        // Scroll the whole report so every part is laid out.
        await _scrollTo(tester, find.byType(OutlinedButton));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final locale in [const Locale('en'), const Locale('bn')]) {
    testWidgets('large system text (1.3x) does not overflow ($locale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        locale: locale,
        show: _session(logs: _manyLogs(), rows: 3, cols: 4),
      );
      await _scrollTo(tester, find.byType(OutlinedButton));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a photo opens the full-screen viewer', (tester) async {
    await _pump(tester, show: _session(logs: _manyLogs()));
    final thumbs = find.byTooltip('View photo');
    await _scrollTo(tester, thumbs.first);
    expect(thumbs, findsNWidgets(2));
    await tester.tap(thumbs.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Photo 2 of 2'), findsOneWidget);
    // Caption names the device.
    expect(find.textContaining('Cam-6'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('export', () {
    testWidgets('shares a PDF with a safe file name for room 12/B', (
      tester,
    ) async {
      final session = _session(logs: _manyLogs());
      final h = await _pump(tester, show: session);
      await _tapExport(tester);

      expect(h.pdf.calls, 1);
      expect(h.share.calls, hasLength(1));
      final call = h.share.calls.single;
      expect(call.fileName, 'examguard_room_12_B_2026-10-13.pdf');
      expect(call.fileName, ReportRepository.reportFileName(session));
      expect(call.fileName, isNot(contains('/')));
      expect(call.mimeType, 'application/pdf');
      expect(call.subject, contains('12/B'));
      expect(call.origin, isNotNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('app bar share icon exports too', (tester) async {
      final h = await _pump(tester, show: _session());
      await tester.tap(find.byTooltip('Export PDF Report'));
      await tester.pump();
      await tester.pump();
      expect(h.share.calls, hasLength(1));
    });

    testWidgets('shows a loader while exporting and ignores a second tap', (
      tester,
    ) async {
      final h = await _pump(tester, show: _session());
      h.share.pending = Completer<ShareOutcome>();
      await _tapExport(tester);

      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
        isTrue,
      );
      expect(h.container.read(reportViewModelProvider).isExporting, isTrue);
      // A second export while busy is ignored.
      await tester.tap(find.byTooltip('Export PDF Report'));
      await tester.pump();
      expect(h.share.calls, hasLength(1));

      h.share.pending!.complete(ShareOutcome.dismissed);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
        isFalse,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('share failure shows an error snackbar, not a crash', (
      tester,
    ) async {
      final h = await _pump(tester, show: _session());
      h.share.error = const ShareFailedException('no activity');
      await _tapExport(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Could not export the report. Please try again.'),
        findsOneWidget,
      );
      final state = h.container.read(reportViewModelProvider);
      expect(state.isExporting, isFalse);
      expect(state.messageKey, 'report_export_failed');
      expect(tester.takeException(), isNull);

      // Retry after the failure works and can fail again visibly.
      ScaffoldMessenger.of(tester.element(find.byType(ReportSummaryScreen)))
          .removeCurrentSnackBar();
      await tester.pump();
      await _tapExport(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.share.calls, hasLength(2));
      expect(
        find.text('Could not export the report. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('pdf build failure also shows the error snackbar', (
      tester,
    ) async {
      final h = await _pump(tester, show: _session());
      h.pdf.fail = true;
      await _tapExport(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.share.calls, isEmpty);
      expect(
        find.text('Could not export the report. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('share unavailable shows its message', (tester) async {
      final h = await _pump(tester, show: _session());
      h.share.outcome = ShareOutcome.unavailable;
      await _tapExport(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Sharing is not available on this device'),
        findsOneWidget,
      );
    });
  });

  group('navigation', () {
    testWidgets('ended session offers a new exam and goes to setup', (
      tester,
    ) async {
      await _pump(tester, show: _session());
      final button = find.text('Start New Exam Session');
      await _scrollTo(tester, button);
      expect(find.text('Create New Incident Entry'), findsNothing);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('SETUP SCREEN'), findsOneWidget);
    });

    testWidgets('running session offers a new incident entry', (tester) async {
      await _pump(tester, show: _session(ended: false));
      expect(find.text('In progress'), findsOneWidget);
      final button = find.text('Create New Incident Entry');
      await _scrollTo(tester, button);
      expect(find.text('Start New Exam Session'), findsNothing);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('ACTION NEW SCREEN'), findsOneWidget);
    });

    testWidgets('just-ended session (endCurrentSession) shows its report', (
      tester,
    ) async {
      final storage = _MemoryStorage()
        ..put(
          _session(
            id: 'old',
            institute: 'Old College',
            start: DateTime(2026, 9, 1),
          ),
        )
        ..put(
          _session(
            id: 'live',
            institute: 'Live College',
            ended: false,
            start: DateTime.now().subtract(const Duration(hours: 1)),
            logs: [_log('Phone-0', LogSeverity.critical)],
          ),
        );
      final container = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      expect(container.read(sessionViewModelProvider)?.id, 'live');
      final ended = await container
          .read(sessionViewModelProvider.notifier)
          .endCurrentSession();
      expect(ended!.isActive, isFalse);
      // Persisted, then shown by a fresh app via openSession(id).
      await _pump(tester, storage: storage, show: ended);
      expect(find.text('Live College'), findsOneWidget);
      expect(find.text('Old College'), findsNothing);
      expect(_metric(tester, 'Critical Violations'), '1');
      expect(find.text('In progress'), findsNothing);
    });

    testWidgets('opening a past session from history shows that session', (
      tester,
    ) async {
      final storage = _MemoryStorage()
        ..put(
          _session(
            id: 'a',
            institute: 'Alpha College',
            room: 'R-ALPHA',
            start: DateTime(2026, 9, 1, 9),
            logs: [
              _log('Phone-0', LogSeverity.high),
              _log('Phone-1', LogSeverity.high),
            ],
          ),
        )
        ..put(
          _session(
            id: 'b',
            institute: 'Beta College',
            room: 'R-BETA',
            start: DateTime(2026, 10, 1, 9),
          ),
        );
      final h = await _pump(
        tester,
        storage: storage,
        initial: AppRoute.history,
      );
      expect(find.byType(HistoryEntryCard), findsNWidgets(2));

      await tester.tap(find.textContaining('R-ALPHA').first);
      await tester.pumpAndSettle();
      expect(find.byType(ReportSummaryScreen), findsOneWidget);
      expect(find.text('Alpha College'), findsOneWidget);
      expect(_metric(tester, 'High Threats'), '2');
      expect(h.container.read(sessionViewModelProvider)?.id, 'a');

      // Back, then the other one.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('R-BETA').first);
      await tester.pumpAndSettle();
      expect(find.text('Beta College'), findsOneWidget);
      expect(find.text('No Incidents Logged'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no session: placeholders and export disabled', (tester) async {
      final h = await _pump(tester);
      expect(find.text('No session'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.share_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      expect(h.share.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
