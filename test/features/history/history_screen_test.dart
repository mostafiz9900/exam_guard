// History screen renders without overflow on a small phone, light and dark,
// and shows the empty state when nothing is saved.

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/history/view/history_screen.dart';
import 'package:exam_guard/features/history/view/widgets/history_entry_card.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

_MemoryStorage _storageWithExams() {
  final storage = _MemoryStorage();
  for (var i = 0; i < 3; i++) {
    final s = SessionModel(
      id: '$i',
      instituteName: 'Dhaka Residential Model College — Main Examination Hall',
      teacherName: 'T',
      roomNumber: '302-B-$i',
      startTime: DateTime(2026, 10, 10 + i, 9),
      endTime: DateTime(2026, 10, 10 + i, 12, 5),
      deviceLogs: [
        for (final sev in [LogSeverity.critical, LogSeverity.high])
          ActionLogModel(
            deviceName: 'Phone',
            deviceId: 'AA',
            category: 'Bluetooth Device',
            severity: sev,
            location: 'Desk',
            notes: '',
            createdAt: DateTime(2026, 10, 10),
          ),
      ],
    );
    storage.values['session_$i'] = s.toJson();
  }
  return storage;
}

Future<void> _pump(
  WidgetTester tester,
  _MemoryStorage storage,
  ThemeMode mode,
) async {
  // Each test loads the translations again.
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(storage)],
        child: Builder(
          builder: (context) => AppScreenSize(
            builder: (_) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const HistoryScreen(),
            ),
          ),
        ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(HistoryScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('lists saved exams on a small phone ($mode)', (tester) async {
      await _pump(tester, _storageWithExams(), mode);
      expect(find.byType(HistoryEntryCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the empty state', (tester) async {
    await _pump(tester, _MemoryStorage(), ThemeMode.light);
    expect(find.byType(HistoryEntryCard), findsNothing);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
