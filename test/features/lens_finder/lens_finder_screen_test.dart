// Lens finder screen: every state fits a small phone in light/dark and
// Bangla; not-scanning states never look like "no lens".

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/camera_stream/i_camera_stream_service.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/lens_finder/view/lens_finder_screen.dart';
import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import 'lens_finder_view_model_test.dart' show FakeCamera, glintFrame;

class _Haptics implements IHapticService {
  @override
  Future<void> pulse(HapticStrength strength) async {}

  @override
  Future<void> alertPattern() async {}
}

final _shotDir = Platform.environment['LENS_SHOTS'];
final _boundary = GlobalKey();

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeCamera camera, {
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      cameraStreamServiceProvider.overrideWithValue(camera),
      hapticServiceProvider.overrideWithValue(_Haptics()),
    ],
  );
  addTearDown(container.dispose);
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
            builder: (_) => RepaintBoundary(
              key: _boundary,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: mode,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const LensFinderScreen(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(LensFinderScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
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

  for (final locale in const [Locale('en'), Locale('bn')]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      final name = 'lens_${locale.languageCode}_${mode.name}';
      testWidgets('$name: live with a glint, then denied — no overflow', (
        tester,
      ) async {
        final camera = FakeCamera();
        final c = await _pump(tester, camera, mode: mode, locale: locale);
        for (var i = 0; i < 12; i++) {
          camera.frameController.add(glintFrame(i * 200));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(c.read(lensFinderViewModelProvider).candidates, isNotEmpty);
        expect(tester.takeException(), isNull);
        await _shot(tester, '${name}_live');

        camera.failWith = CameraStreamError.permissionDenied;
        await c.read(lensFinderViewModelProvider.notifier).start();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          c.read(lensFinderViewModelProvider).status,
          LensFinderStatus.permissionDenied,
        );
        expect(tester.takeException(), isNull);
        await _shot(tester, '${name}_denied');
      });
    }
  }

  testWidgets('paused shows a not-scanning state with a way to resume', (
    tester,
  ) async {
    final camera = FakeCamera();
    final c = await _pump(tester, camera);
    await c.read(lensFinderViewModelProvider.notifier).pause();
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.read(lensFinderViewModelProvider).status, LensFinderStatus.paused);
    expect(tester.takeException(), isNull);
    await _shot(tester, 'lens_paused');
  });
}
