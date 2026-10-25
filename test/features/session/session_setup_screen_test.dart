// Exam setup screen: layout on a small phone in every language and theme,
// and the validation flow.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/session/view/session_setup_screen.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;

class _Storage implements ILocalStorage {
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

final _shotDir = Platform.environment['SETUP_SHOTS'];
final _boundary = GlobalKey();

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [localStorageProvider.overrideWithValue(_Storage())],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoute.sessionSetup,
    routes: [
      GoRoute(
        path: AppRoute.sessionSetup,
        builder: (_, _) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: AppRoute.dashboard,
        builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
      ),
      GoRoute(
        path: AppRoute.history,
        builder: (_, _) => const Scaffold(body: Text('HISTORY')),
      ),
    ],
  );
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
              child: MaterialApp.router(
                routerConfig: router,
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
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(SessionSetupScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 600));
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

Finder _input(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

Future<void> _start(WidgetTester tester) async {
  final button = find.text('Start monitoring');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadFonts();
  });

  for (final locale in const [Locale('en'), Locale('bn'), Locale('ar')]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      final name = 'setup_${locale.languageCode}_${mode.name}';
      testWidgets('$name: empty, errors and preview fit a small phone', (
        tester,
      ) async {
        await _pump(tester, mode: mode, locale: locale);
        expect(tester.takeException(), isNull);
        await _shot(tester, name);

        // Errors everywhere at once.
        await tester.enterText(_input('setup_supervisor'), 'A');
        await tester.enterText(find.byKey(const Key('seat_rows')), '40');
        await tester.ensureVisible(find.byKey(const Key('setup_room')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('setup_start')), warnIfMissed: false);
        // Errors fade in; the screen scrolls to the first field to fix.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull);
        await _shot(tester, '${name}_errors');

        // Seat preview.
        await tester.enterText(find.byKey(const Key('seat_rows')), '6');
        await tester.enterText(find.byKey(const Key('seat_cols')), '30');
        await tester.enterText(_input('setup_supervisor'), 'Dr. Rahman');
        await tester.enterText(_input('setup_room'), '302-B');
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.ensureVisible(find.byKey(const Key('seat_preview')));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull);
        await _shot(tester, '${name}_preview');
      });
    }
  }

  testWidgets('empty room: errors shown, focus jumps to the room field', (
    tester,
  ) async {
    final container = await _pump(tester);
    await _start(tester);
    expect(find.text('Please enter a room number.'), findsOneWidget);
    expect(find.byKey(const Key('setup_fix_banner')), findsOneWidget);
    final room = tester.widget<EditableText>(_input('setup_room'));
    expect(room.focusNode.hasFocus, isTrue);
    expect(container.read(sessionViewModelProvider), isNull);
  });

  testWidgets('errors update live after the first try and clear when fixed', (
    tester,
  ) async {
    await _pump(tester);
    await _start(tester);
    await tester.enterText(_input('setup_room'), '302-B');
    // The old error fades out (the frame after the fade removes it).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    // Judge the field, not the text: InputDecorator keeps the old error
    // widget in its crossfade stack.
    final room = tester.state<FormFieldState<String>>(
      find.descendant(
        of: find.byKey(const Key('setup_room')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(room.hasError, isFalse);
    expect(find.byKey(const Key('setup_fix_banner')), findsNothing);
  });

  testWidgets('invalid characters are blocked while typing', (tester) async {
    await _pump(tester);
    await tester.enterText(_input('setup_room'), '3@0!2');
    await tester.enterText(_input('setup_supervisor'), 'Dr. Rahman 2!');
    await tester.enterText(_input('setup_institute'), 'Central <College>');
    await tester.pump();
    expect(find.text('302'), findsOneWidget);
    expect(find.text('Dr. Rahman '), findsOneWidget);
    expect(find.text('Central College'), findsOneWidget);
  });

  testWidgets('length limits are enforced with a counter', (tester) async {
    await _pump(tester);
    await tester.enterText(_input('setup_room'), 'A' * 30);
    await tester.pump();
    expect(find.text('A' * 20), findsOneWidget);
    expect(find.text('20/20'), findsOneWidget);
  });

  testWidgets('only the wrong seat field is flagged, with the reason', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_input('setup_room'), '204');
    await tester.enterText(find.byKey(const Key('seat_rows')), '6');
    await _start(tester);
    expect(
      find.text('Enter both rows and columns, or leave both empty.'),
      findsOneWidget,
    );
    final cols = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('seat_cols')),
        matching: find.byType(EditableText),
      ),
    );
    expect(cols.focusNode.hasFocus, isTrue);
  });

  testWidgets('seat preview shows the total while typing', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('seat_rows')), '6');
    await tester.enterText(find.byKey(const Key('seat_cols')), '5');
    await tester.pump();
    expect(find.text('30 seats'), findsOneWidget);
    expect(find.text('6 rows × 5 columns'), findsOneWidget);
  });

  testWidgets('a valid form starts the exam with cleaned values', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.enterText(_input('setup_room'), '  302-B ');
    await tester.enterText(_input('setup_institute'), 'Central   College');
    await tester.enterText(_input('setup_supervisor'), ' Dr. Rahman ');
    await tester.enterText(find.byKey(const Key('seat_rows')), '6');
    await tester.enterText(find.byKey(const Key('seat_cols')), '5');
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final s = container.read(sessionViewModelProvider)!;
    expect(s.roomNumber, '302-B');
    expect(s.instituteName, 'Central College');
    expect(s.teacherName, 'Dr. Rahman');
    expect((s.seatRows, s.seatCols), (6, 5));
    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
