// Splash and introduction pages on a small phone, light/dark, en/bn/ar.
// Screenshots: ONB_SHOTS=<dir> flutter test <this file>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/onboarding/view/onboarding_screen.dart';
import 'package:exam_guard/features/onboarding/view/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import '../node_setup/node_fakes.dart' show FakeStorage;

class _Permissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.denied;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

final _shotDir = Platform.environment['ONB_SHOTS'];
final _boundary = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  String initial, {
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('setup')),
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
          localStorageProvider.overrideWithValue(FakeStorage()),
          permissionServiceProvider.overrideWithValue(_Permissions()),
        ],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              builder: (_, child) =>
                  RepaintBoundary(key: _boundary, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 40 && find.byType(Scaffold).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let Image.asset decode the emblem.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final image = (e.widget as Image).image;
      await precacheImage(image, e);
    }
  });
  await tester.pump();
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

  testWidgets('splash goes to the introduction on first run', (tester) async {
    SplashScreen.hold = const Duration(seconds: 5);
    addTearDown(() => SplashScreen.hold = const Duration(milliseconds: 1600));
    await _pump(tester, '/splash');
    expect(find.byKey(const Key('splash_emblem')), findsOneWidget);
    expect(find.text('Pahara'), findsOneWidget);
    expect(find.text('Exam Hall Security'), findsOneWidget);
    await _shot(tester, 'splash');
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      final tag = '${locale.languageCode}_${mode.name}';
      testWidgets('introduction $tag: every page fits', (tester) async {
        await _pump(tester, '/welcome', mode: mode, locale: locale);
        for (var page = 0; page < 5; page++) {
          expect(tester.takeException(), isNull, reason: 'page $page');
          await _shot(tester, 'onb_${tag}_$page');
          if (page < 4) {
            await tester.tap(find.byKey(const Key('onb_next')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
        await tester.tap(find.byKey(const Key('onb_allow')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('onb_perm_result')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _shot(tester, 'onb_${tag}_perm_result');
      });
    }
  }
}
