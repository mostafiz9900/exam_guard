// Every text field uses appTextContextMenu: iOS's native SystemContextMenu
// asserts when a menu is rebuilt within one frame (e.g. a formatter
// rewriting a paste). See lib/core/widgets/app_text_context_menu.dart.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every TextField / TextFormField in lib/ sets the app menu', () {
    final field = RegExp(r'\b(TextField|TextFormField)\(');
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final fields = field.allMatches(src).length;
      final menus = 'contextMenuBuilder: appTextContextMenu'
          .allMatches(src)
          .length;
      if (fields > menus) {
        missing.add('${f.path}: $fields fields, $menus menus');
      }
    }
    expect(missing, isEmpty);
  });

  testWidgets('the menu is the Flutter-drawn adaptive toolbar', (tester) async {
    final controller = TextEditingController(text: 'room 302');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            contextMenuBuilder: appTextContextMenu,
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.byType(SystemContextMenu), findsNothing);
  });
}
