// Every literal key passed to .tr() exists in every language, and all
// languages define the same keys: a missing key shows up on screen as the
// raw key (e.g. "radar_band_range").

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  const languages = ['en', 'bn', 'ar'];
  final translations = {for (final l in languages) l: _load(l)};

  test('all languages define the same keys', () {
    final en = translations['en']!.keys.toSet();
    for (final l in languages.skip(1)) {
      final keys = translations[l]!.keys.toSet();
      expect(en.difference(keys), isEmpty, reason: 'missing in $l');
      expect(keys.difference(en), isEmpty, reason: 'only in $l');
    }
  });

  test('every literal .tr() key in lib/ is translated', () {
    final used = <String, String>{};
    final pattern = RegExp(r"""'([a-z][a-z0-9_]*)'\s*\.tr\(""");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        used[m.group(1)!] = f.path;
      }
    }
    expect(used, isNotEmpty);
    for (final l in languages) {
      final missing = {
        for (final e in used.entries)
          if (!translations[l]!.containsKey(e.key)) e.key: e.value,
      };
      expect(missing, isEmpty, reason: 'keys missing in $l.json');
    }
  });
}
