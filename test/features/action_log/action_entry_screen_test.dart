// Incident form (ActionEntryScreen) with its seat picker sheet and photo
// evidence section: layout on a small phone, prefill from a scanner,
// validation, category/severity, seats, photos, saving and leaving.
//
// Regression: the seat picker's "Invigilator desk / Front" banner is sized
// to the grid, so on 2-3 column rooms its label must ellipsize instead of
// overflowing (was 51 px / 9 px over at 320 px wide).
//
// Camera and share sheet are faked through provider overrides; nothing
// touches a real plugin.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/view/action_entry_screen.dart';
import 'package:exam_guard/features/action_log/view/widgets/photo_evidence_section.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../responsive/responsive_test.dart' show loadFonts;
import '../session_provider_test.dart' show InMemoryStorage;

/// Hands out numbered photo paths and records deletions.
class _FakePhotoService implements IPhotoService {
  final deleted = <String>[];
  var taken = 0;
  Object? error;
  bool cancel = false;

  /// When set, [takePhoto] waits for it (camera "open").
  Completer<void>? gate;

  @override
  Future<String?> takePhoto() async {
    await gate?.future;
    if (error != null) throw error!;
    if (cancel) return null;
    return '/photos/${++taken}.jpg';
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<bool> exists(String path) async => !deleted.contains(path);
}

class _FakeShareService implements IShareService {
  final texts = <String>[];
  final subjects = <String?>[];
  ShareOutcome outcome = ShareOutcome.shared;
  Object? error;

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    if (error != null) throw error!;
    texts.add(text);
    subjects.add(subject);
    return outcome;
  }

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  }) async => throw UnimplementedError();
}

const _homeText = 'TEST HOME';

class _Harness {
  _Harness(this.container, this.photos, this.share, this.router);

  final ProviderContainer container;
  final _FakePhotoService photos;
  final _FakeShareService share;
  final GoRouter router;

  List<ActionLogModel> get logs =>
      container.read(sessionViewModelProvider)?.deviceLogs ?? const [];
}

Future<_Harness> _pump(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  ActionEntryArgs args = const ActionEntryArgs(),
  int? seatRows,
  int? seatCols,
  List<ActionLogModel> existingLogs = const [],
  bool session = true,
  Locale locale = const Locale('en'),
}) async {
  // Each test loads the translations again.
  rootBundle.clear();
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final photos = _FakePhotoService();
  final share = _FakeShareService();
  final container = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(InMemoryStorage()),
      photoServiceProvider.overrideWithValue(photos),
      shareServiceProvider.overrideWithValue(share),
    ],
  );
  addTearDown(container.dispose);
  if (session) {
    final sessions = container.read(sessionViewModelProvider.notifier);
    await sessions.createSession(
      instituteName: 'Dhaka College',
      teacherName: 'Rahim',
      roomNumber: '302-B',
      seatRows: seatRows,
      seatCols: seatCols,
    );
    for (final log in existingLogs) {
      await sessions.addLog(log);
    }
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text(_homeText))),
      ),
      GoRoute(
        path: '/action/new',
        builder: (context, state) => ActionEntryScreen(
          args: state.extra is ActionEntryArgs
              ? state.extra! as ActionEntryArgs
              : const ActionEntryArgs(),
        ),
      ),
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
  for (var i = 0; i < 40 && find.text(_homeText).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text(_homeText), findsOneWidget);

  unawaited(router.push('/action/new', extra: args));
  await tester.pumpAndSettle();
  expect(find.byType(ActionEntryScreen), findsOneWidget);
  return _Harness(container, photos, share, router);
}

Finder _field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

String _fieldText(WidgetTester tester, String hint) =>
    tester.widget<TextField>(_field(hint)).controller!.text;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String hint, String text) async {
  await tester.ensureVisible(_field(hint));
  await tester.enterText(_field(hint), text);
  await tester.pump();
}

const _nameHint = 'Device / threat name';
const _idHint = 'Device ID / serial number (optional)';
const _locationHint = 'Location / desk / seat number';
const _locationNoteHint = 'Location note (optional)';
const _notesHint = 'Invigilator notes / comments';
const _invalidMsg = 'Pick a seat, or enter a device name or location note.';

final _device = ScannedDeviceModel(
  id: 'AA:BB:CC:DD:EE:FF',
  name: 'Spy Earpiece X1',
  manufacturer: 'Generic Bluetooth',
  deviceType: 'Audio Headset',
  rssi: -48,
  transport: DeviceTransport.classic,
  lastSeen: DateTime(2026, 10, 10, 9),
  firstSeen: DateTime(2026, 10, 10, 9),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // Real Roboto/MaterialIcons so overflow checks match real phones.
    await loadFonts();
  });

  group('layout on a small phone', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('fresh incident renders without overflow ($mode)', (
        tester,
      ) async {
        await _pump(tester, mode: mode);
        expect(find.text('Log action'), findsOneWidget);
        expect(find.text('Bluetooth / BLE device'), findsOneWidget);
        expect(_fieldText(tester, _nameHint), isEmpty);
        expect(_fieldText(tester, _idHint), isEmpty);
        expect(_field(_locationHint), findsOneWidget);
        expect(find.text('Seat'), findsNothing);
        expect(find.byType(PhotoEvidenceSection), findsOneWidget);
        expect(find.text('0 / 4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('prefilled from a detected device renders ($mode)', (
        tester,
      ) async {
        await _pump(
          tester,
          mode: mode,
          seatRows: 6,
          seatCols: 8,
          args: ActionEntryArgs(device: _device, notes: 'Seen near row C'),
        );
        expect(_fieldText(tester, _nameHint), 'Spy Earpiece X1');
        expect(_fieldText(tester, _idHint), 'AA:BB:CC:DD:EE:FF');
        expect(_fieldText(tester, _notesHint), 'Seen near row C');
        // Classic audio device defaults to the earpiece category.
        expect(find.text('Classic Bluetooth earpiece'), findsOneWidget);
        expect(find.text('Seat'), findsOneWidget);
        expect(_field(_locationNoteHint), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('open keyboard does not overflow', (tester) async {
      await _pump(tester, seatRows: 4, seatCols: 4);
      await tester.tap(_field(_nameHint));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _enter(tester, _notesHint, 'A long note\nwith lines\nand more');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Fields below the keyboard remain reachable by scrolling.
      await tester.ensureVisible(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('scanner category without a label is offered as passed', (
      tester,
    ) async {
      await _pump(
        tester,
        args: const ActionEntryArgs(category: 'Ultrasonic Beacon'),
      );
      expect(find.text('Ultrasonic Beacon'), findsOneWidget);
      await _enter(tester, _nameHint, 'Beacon');
      await _tap(tester, find.text('Save record'));
      // Unknown categories are still stored as given.
      expect(find.text(_homeText), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('empty form shows the error and stores nothing', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Save record'));
      expect(find.text(_invalidMsg), findsOneWidget);
      expect(find.byType(ActionEntryScreen), findsOneWidget);
      expect(h.logs, isEmpty);
    });

    testWidgets('whitespace only is rejected, Save & share too', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _enter(tester, _nameHint, '   ');
      await _enter(tester, _locationHint, '  ');
      await _tap(tester, find.text('Save & share report'));
      expect(find.text(_invalidMsg), findsOneWidget);
      expect(find.text('Incident saved — violation report'), findsNothing);
      expect(h.logs, isEmpty);
    });

    testWidgets('a location note alone is enough', (tester) async {
      final h = await _pump(tester);
      await _enter(tester, _locationHint, 'Back row, desk 12');
      await _tap(tester, find.text('Save record'));
      expect(h.logs.single.location, 'Back row, desk 12');
      expect(h.logs.single.deviceName, 'Unknown Device');
      expect(h.logs.single.deviceId, 'N/A');
    });

    testWidgets('saving after the exam ended shows an error and stays', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.container
          .read(sessionViewModelProvider.notifier)
          .endCurrentSession();
      await tester.pump();
      await _enter(tester, _nameHint, 'Phone');
      await _tap(tester, find.text('Save record'));
      expect(
        find.text('The exam has ended; incidents can no longer be added.'),
        findsOneWidget,
      );
      expect(find.byType(ActionEntryScreen), findsOneWidget);
      expect(h.logs, isEmpty);
    });
  });

  group('saving', () {
    testWidgets('Save stores the chosen fields and goes back', (tester) async {
      final h = await _pump(tester);

      // Category.
      await _tap(tester, find.text('Bluetooth / BLE device'));
      await _tap(tester, find.text('Magnetic / EMP anomaly').last);
      expect(find.text('Magnetic / EMP anomaly'), findsOneWidget);

      // Severity.
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Low'));
      final low = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Low'),
      );
      expect(low.selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'High'))
            .selected,
        isFalse,
      );

      await _enter(tester, _nameHint, '  Smart Watch  ');
      await _enter(tester, _idHint, 'SN-1234');
      await _enter(tester, _locationHint, 'Desk 7');
      await _enter(tester, _notesHint, 'Hidden under sleeve');
      await _tap(tester, find.text('Save record'));

      expect(find.text('Violation incident logged.'), findsOneWidget);
      expect(find.text(_homeText), findsOneWidget);
      expect(find.byType(ActionEntryScreen), findsNothing);

      final log = h.logs.single;
      expect(log.deviceName, 'Smart Watch');
      expect(log.deviceId, 'SN-1234');
      expect(log.category, 'Magnetic Anomaly');
      expect(log.severity, LogSeverity.low);
      expect(log.location, 'Desk 7');
      expect(log.notes, 'Hidden under sleeve');
      expect(log.seat, isNull);
      expect(log.photoPaths, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('prefilled device saves with default category and severity', (
      tester,
    ) async {
      final h = await _pump(tester, args: ActionEntryArgs(device: _device));
      await _tap(tester, find.text('Save record'));
      final log = h.logs.single;
      expect(log.deviceName, 'Spy Earpiece X1');
      expect(log.deviceId, 'AA:BB:CC:DD:EE:FF');
      expect(log.category, 'Classic Bluetooth Earpiece');
      expect(log.severity, LogSeverity.high);
      expect(find.text(_homeText), findsOneWidget);
    });

    testWidgets('Save & share shows the report and shares it', (tester) async {
      final h = await _pump(tester, args: ActionEntryArgs(device: _device));
      await _tap(tester, find.text('Save & share report'));

      expect(h.logs, hasLength(1));
      expect(find.text('Incident saved — violation report'), findsOneWidget);
      expect(find.textContaining('Spy Earpiece X1'), findsWidgets);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.text('Share'));
      expect(h.share.texts.single, contains('Spy Earpiece X1'));
      expect(h.share.texts.single, contains('-48 dBm'));
      expect(h.share.subjects.single, contains('302-B'));
      expect(find.text(_homeText), findsOneWidget);
    });

    testWidgets('share failure shows a message after going back', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.share.error = const ShareFailedException('boom');
      await _enter(tester, _nameHint, 'Phone');
      await _tap(tester, find.text('Save & share report'));
      await _tap(tester, find.text('Share'));
      expect(
        find.text('Could not share the report. Please try again.'),
        findsOneWidget,
      );
      expect(find.text(_homeText), findsOneWidget);
      expect(h.logs, hasLength(1));
    });

    testWidgets('report sheet Done closes the form without sharing', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _enter(tester, _nameHint, 'Phone');
      await _tap(tester, find.text('Save & share report'));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _tap(tester, find.text('Copy text'));
      expect(copied, contains('Phone'));
      expect(find.text('Report text copied to clipboard'), findsOneWidget);
      await _tap(tester, find.text('Done'));
      expect(h.share.texts, isEmpty);
      expect(find.text(_homeText), findsOneWidget);
      expect(h.logs, hasLength(1));
    });
  });

  group('seat picker', () {
    testWidgets('no seat layout: no seat field, location hint for seats', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Tap to choose the seat on the room map'), findsNothing);
      expect(find.byIcon(Icons.event_seat_outlined), findsNothing);
      expect(_field(_locationHint), findsOneWidget);
    });

    testWidgets('picking a seat fills the seat field and is saved', (
      tester,
    ) async {
      final h = await _pump(tester, seatRows: 4, seatCols: 5);
      expect(
        find.text('Tap to choose the seat on the room map'),
        findsOneWidget,
      );

      await _tap(tester, find.byIcon(Icons.event_seat_outlined));
      expect(find.text('Choose the seat'), findsOneWidget);
      expect(find.text('Invigilator desk / Front'), findsOneWidget);
      // No incidents yet: no legend.
      expect(find.text('Already has incidents (number = count)'), findsNothing);
      expect(find.text('D5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.text('B3'));
      expect(find.text('Choose the seat'), findsNothing);
      expect(find.text('B3'), findsOneWidget);

      // Seat alone is enough to save.
      await _tap(tester, find.text('Save record'));
      expect(h.logs.single.seat, 'B3');
      expect(h.logs.single.location, isEmpty);
    });

    testWidgets('dismissing the sheet keeps the field empty', (tester) async {
      await _pump(tester, seatRows: 4, seatCols: 4);
      await _tap(tester, find.byIcon(Icons.event_seat_outlined));
      expect(find.text('Choose the seat'), findsOneWidget);
      await tester.tapAt(const Offset(160, 20));
      await tester.pumpAndSettle();
      expect(find.text('Choose the seat'), findsNothing);
      expect(
        find.text('Tap to choose the seat on the room map'),
        findsOneWidget,
      );
    });

    testWidgets('seats with incidents are marked; clearing the seat works', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        seatRows: 4,
        seatCols: 4,
        existingLogs: [
          for (var i = 0; i < 2; i++)
            ActionLogModel(
              deviceName: 'Phone',
              deviceId: 'AA',
              category: 'Bluetooth Device',
              severity: LogSeverity.critical,
              location: '',
              notes: '',
              createdAt: DateTime(2026, 10, 10),
              seat: 'A2',
            ),
        ],
      );
      await _tap(tester, find.byIcon(Icons.event_seat_outlined));
      expect(
        find.text('Already has incidents (number = count)'),
        findsOneWidget,
      );
      expect(find.text('2'), findsWidgets); // count badge (and column 2)
      await _tap(tester, find.text('C1'));
      expect(find.text('C1'), findsOneWidget);

      await _tap(tester, find.byTooltip('Clear seat'));
      expect(find.text('C1'), findsNothing);
      expect(
        find.text('Tap to choose the seat on the room map'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Save record'));
      expect(find.text(_invalidMsg), findsOneWidget);
      expect(h.logs, hasLength(2));
    });

    for (final cols in const [2, 3]) {
      testWidgets('a small room ($cols columns) seat map does not overflow', (
        tester,
      ) async {
        await _pump(tester, seatRows: 3, seatCols: cols);
        await _tap(tester, find.byIcon(Icons.event_seat_outlined));
        expect(find.text('Choose the seat'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('large seat map on a small phone does not overflow', (
      tester,
    ) async {
      await _pump(tester, seatRows: 14, seatCols: 12);
      await _tap(tester, find.byIcon(Icons.event_seat_outlined));
      expect(find.text('Choose the seat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('photo evidence', () {
    testWidgets('adding and removing photos', (tester) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Add photo'));
      await _tap(tester, find.text('Add photo'));
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.byTooltip('Remove photo'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await _tap(tester, find.byTooltip('Remove photo').first);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(h.photos.deleted, ['/photos/1.jpg']);

      await _enter(tester, _nameHint, 'Phone');
      await _tap(tester, find.text('Save record'));
      expect(h.logs.single.photoPaths, ['/photos/2.jpg']);
      // Saved photos belong to the incident: not deleted on leaving.
      await tester.pumpAndSettle();
      expect(h.photos.deleted, ['/photos/1.jpg']);
    });

    testWidgets('shows progress while the camera is open', (tester) async {
      final h = await _pump(tester);
      h.photos.gate = Completer<void>();
      await tester.ensureVisible(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add photo'));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(PhotoEvidenceSection),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      h.photos.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('1 / 4'), findsOneWidget);
    });

    testWidgets('the add tile disappears at the limit', (tester) async {
      final h = await _pump(tester);
      for (var i = 0; i < 4; i++) {
        await _tap(tester, find.text('Add photo'));
      }
      expect(find.text('4 / 4'), findsOneWidget);
      expect(find.text('Add photo'), findsNothing);
      expect(h.photos.taken, 4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('camera failure or denied permission shows an error', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.photos.error = const PhotoException('Camera permission denied');
      await _tap(tester, find.text('Add photo'));
      expect(
        find.text('Could not take the photo. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('0 / 4'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);

      // An unexpected error is reported the same way.
      h.photos.error = StateError('plugin crashed');
      await _tap(tester, find.text('Add photo'));
      expect(find.text('0 / 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the camera adds nothing and shows nothing', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.photos.cancel = true;
      await _tap(tester, find.text('Add photo'));
      expect(find.text('0 / 4'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('leaving without saving', () {
    testWidgets('back without photos leaves at once and stores nothing', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _enter(tester, _nameHint, 'Phone');
      await _tap(tester, find.byType(BackButton));
      expect(find.text(_homeText), findsOneWidget);
      expect(find.text('Discard this incident?'), findsNothing);
      expect(h.logs, isEmpty);
    });

    testWidgets('back with photos asks; keep editing stays', (tester) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Add photo'));
      await _tap(tester, find.byType(BackButton));
      expect(find.text('Discard this incident?'), findsOneWidget);
      await _tap(tester, find.text('Keep editing'));
      expect(find.byType(ActionEntryScreen), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(h.photos.deleted, isEmpty);
    });

    testWidgets('back with photos, discard deletes them and leaves', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _tap(tester, find.text('Add photo'));
      await _tap(tester, find.text('Add photo'));
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.text('Discard'));
      expect(find.text(_homeText), findsOneWidget);
      expect(find.byType(ActionEntryScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(
        h.photos.deleted,
        unorderedEquals(['/photos/1.jpg', '/photos/2.jpg']),
      );
      expect(h.logs, isEmpty);
    });
  });
}
