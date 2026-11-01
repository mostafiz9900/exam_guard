// Turn-around direction finding on the radar: the view model with a fake
// compass and fake BLE packets, and the sheet on a small phone.
// Screenshots: DIR_SHOTS=<dir> flutter test <this file>

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/sensors/heading_service_impl.dart';
import 'package:exam_guard/core/services/sensors/i_heading_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/radar/model/direction_finder.dart';
import 'package:exam_guard/features/radar/repository/direction_repository.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view/widgets/direction_finder_sheet.dart';
import 'package:exam_guard/features/radar/view_model/direction_finder_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import '../node_setup/node_fakes.dart' show FakeSession;
import 'finder_fakes.dart';

class _Repo implements DirectionRepository {
  final heading = StreamController<HeadingReading>.broadcast();
  final signal = StreamController<RadarSignal>.broadcast();
  final fronts = <String, double>{};
  bool noCompass = false;

  void face(double deg, {bool calibrate = false}) => heading.add(
    HeadingReading(degrees: deg % 360, needsCalibration: calibrate),
  );

  void packet(String id, int rssi) => signal.add(
    RadarSignal(rssi: rssi, timestamp: DateTime.now(), deviceId: id),
  );

  @override
  Stream<HeadingReading> headings() => noCompass
      ? Stream.error(const HeadingUnavailableException())
      : heading.stream;

  @override
  Stream<RadarSignal> signals() => signal.stream;

  @override
  double? frontHeading(String room) => fronts[room];

  @override
  Future<void> saveFront(String room, double heading) async =>
      fronts[room] = heading;
}

/// The device sits at [target]°; body shadow 15 dB behind the person.
int _rssiFacing(double heading, double target) =>
    (-60 - 15 * (1 - math.cos((heading - target) * math.pi / 180)) / 2).round();

void main() {
  group('view model', () {
    late _Repo repo;
    late ProviderContainer c;
    DirectionState read() => c.read(directionFinderViewModelProvider);
    DirectionFinderViewModel vm() =>
        c.read(directionFinderViewModelProvider.notifier);

    /// Waits past the ~15 Hz state throttle.
    Future<void> tick() =>
        Future<void>.delayed(const Duration(milliseconds: 70));

    setUp(() {
      repo = _Repo();
      c = ProviderContainer(
        overrides: [
          directionRepositoryProvider.overrideWithValue(repo),
          sessionViewModelProvider.overrideWith(FakeSession.new),
          scannerViewModelProvider.overrideWith(
            () => FakeScanner({
              'AA': {'AA', 'BB'},
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(directionFinderViewModelProvider, (_, _) {});
    });

    /// One slow turn in 10° steps, a packet from the device at each.
    Future<void> turnAround({required double target, String id = 'AA'}) async {
      for (var h = 0.0; h < 360; h += 10) {
        repo.face(h);
        await tick();
        repo.packet(id, _rssiFacing(h, target));
        await pumpEventQueue();
      }
    }

    test('a full turn points at the device and finishes by itself', () async {
      repo.face(0);
      await tick();
      vm().start('AA');
      expect(read().phase, DirectionPhase.turning);
      await turnAround(target: 135);
      expect(read().phase, DirectionPhase.done);
      final r = read().result!;
      expect(turnTo(r.bearing, 135).abs(), lessThan(12));
      expect(r.confidence, DirectionConfidence.good);
    });

    test('packets from the device\'s other address count too', () async {
      repo.face(0);
      await tick();
      vm().start('AA');
      await turnAround(target: 250, id: 'BB');
      expect(read().result, isNotNull);
    });

    test('other devices are ignored', () async {
      repo.face(0);
      await tick();
      vm().start('AA');
      await turnAround(target: 90, id: 'OTHER');
      expect(read().coverage, 0);
      vm().finish();
      expect(read().result, isNull, reason: 'nothing measured');
    });

    test('stopping half way is "incomplete", not a guess', () async {
      repo.face(0);
      await tick();
      vm().start('AA');
      for (var h = 0.0; h < 150; h += 10) {
        repo.face(h);
        await tick();
        repo.packet('AA', _rssiFacing(h, 60));
        await pumpEventQueue();
      }
      vm().finish();
      expect(read().phase, DirectionPhase.done);
      expect(read().result, isNull);
    });

    test('turning too fast is flagged', () async {
      repo.face(0);
      await tick();
      vm().start('AA');
      repo.face(90); // 90° in ~70 ms
      await tick();
      repo.face(180);
      await tick();
      expect(read().tooFast, isTrue);
    });

    test(
      'front of the hall is saved per room from the recent heading',
      () async {
        for (final h in const <double>[88, 90, 92]) {
          repo.face(h);
          await tick();
        }
        expect(await vm().setFront(), isTrue);
        expect(read().frontHeading, closeTo(90, 1));
        expect(repo.fronts.values.single, closeTo(90, 1));
      },
    );

    test('front across north averages correctly (359° and 1°)', () async {
      repo.face(359);
      await tick();
      repo.face(1);
      await tick();
      await vm().setFront();
      final f = read().frontHeading!;
      expect(math.min(f, 360 - f), lessThan(1.5));
    });

    test('no compass is reported and Start does nothing', () async {
      repo.noCompass = true;
      final c2 = ProviderContainer(
        overrides: [
          directionRepositoryProvider.overrideWithValue(repo),
          sessionViewModelProvider.overrideWith(FakeSession.new),
          scannerViewModelProvider.overrideWith(FakeScanner.new),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(directionFinderViewModelProvider, (_, _) {});
      await pumpEventQueue();
      expect(
        c2.read(directionFinderViewModelProvider).headingUnavailable,
        isTrue,
      );
      c2.read(directionFinderViewModelProvider.notifier).start('AA');
      expect(
        c2.read(directionFinderViewModelProvider).phase,
        DirectionPhase.ready,
      );
    });

    test('native events parse on both platforms', () {
      final a = HeadingServiceImpl.parse([370.0, 3], isIOS: false)!;
      expect(a.degrees, 10);
      expect(a.needsCalibration, isFalse);
      expect(
        HeadingServiceImpl.parse([10.0, 1], isIOS: false)!.needsCalibration,
        isTrue,
      );
      expect(
        HeadingServiceImpl.parse([10.0, -1], isIOS: true)!.needsCalibration,
        isTrue,
      );
      expect(HeadingServiceImpl.parse([-1.0, 2], isIOS: true), isNull);
      expect(HeadingServiceImpl.parse('x', isIOS: true), isNull);
    });
  });

  group('sheet', () {
    final shotDir = Platform.environment['DIR_SHOTS'];
    final boundary = GlobalKey();
    final device = ScannedDeviceModel(
      id: 'AA',
      name: 'Mini Earbud',
      deviceType: 'Smart Earpiece / Audio',
      rssi: -60,
      lastSeen: DateTime(2026),
      firstSeen: DateTime(2026),
    );

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await loadFonts();
    });

    Future<_Repo> pump(
      WidgetTester tester, {
      ThemeMode mode = ThemeMode.light,
      Locale locale = const Locale('en'),
      double? front,
    }) async {
      final repo = _Repo();
      if (front != null) repo.fronts['302-B'] = front;
      rootBundle.clear();
      tester.view.physicalSize = const Size(360, 760);
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
              directionRepositoryProvider.overrideWithValue(repo),
              sessionViewModelProvider.overrideWith(FakeSession.new),
              scannerViewModelProvider.overrideWith(FakeScanner.new),
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
                  home: RepaintBoundary(
                    key: boundary,
                    child: Scaffold(body: DirectionFinderSheet(device: device)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.byType(DirectionFinderSheet).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      return repo;
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

    /// Real time is needed: the view model throttles on DateTime.now().
    Future<void> face(WidgetTester tester, _Repo repo, double deg) async {
      repo.face(deg);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 70)),
      );
      await tester.pump();
    }

    Future<void> fullTurn(
      WidgetTester tester,
      _Repo repo,
      double target,
    ) async {
      for (var h = 0.0; h < 360; h += 10) {
        await face(tester, repo, h);
        repo.packet('AA', _rssiFacing(h, target));
        await tester.pump();
      }
      await tester.pump();
    }

    testWidgets('ready → turning → arrow and words, with hall front', (
      tester,
    ) async {
      final repo = await pump(tester, front: 0);
      await face(tester, repo, 0);
      expect(find.text('Start turning'), findsOneWidget);
      await shot(tester, 'dir_ready');

      await tester.tap(find.byKey(const Key('dir_start')));
      await tester.pump();
      for (var h = 0.0; h < 200; h += 10) {
        await face(tester, repo, h);
        repo.packet('AA', _rssiFacing(h, 225));
        await tester.pump();
      }
      expect(find.byKey(const Key('dir_progress')), findsOneWidget);
      await shot(tester, 'dir_turning');
      await fullTurn(tester, repo, 225);
      expect(find.byKey(const Key('dir_hall_word')), findsOneWidget);
      // Front = north, device at 225° → back-left; compass south-west.
      expect(find.text('Back-left'), findsOneWidget);
      expect(find.textContaining('South-west'), findsOneWidget);
      expect(find.byKey(const Key('dir_turn_hint')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await shot(tester, 'dir_done');
    });

    testWidgets('without a hall front it gives the compass direction and '
        'offers to set the front', (tester) async {
      final repo = await pump(tester);
      await face(tester, repo, 0);
      await tester.tap(find.byKey(const Key('dir_start')));
      await tester.pump();
      await fullTurn(tester, repo, 90);
      expect(find.byKey(const Key('dir_hall_word')), findsNothing);
      expect(find.textContaining('East'), findsOneWidget);
      expect(find.byKey(const Key('dir_set_front')), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        final tag = '${locale.languageCode}_${mode.name}';
        testWidgets('sheet $tag fits', (tester) async {
          final repo = await pump(
            tester,
            mode: mode,
            locale: locale,
            front: 30,
          );
          await face(tester, repo, 10);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('dir_start')));
          await tester.pump();
          await fullTurn(tester, repo, 300);
          expect(tester.takeException(), isNull);
          await shot(tester, 'dir_${tag}_done');
        });
      }
    }
  });
}
