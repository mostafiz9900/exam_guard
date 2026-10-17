import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/core/settings/theme_mode_view_model.dart';

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

void main() {
  test('theme mode is saved and restored', () async {
    final storage = _MemoryStorage();
    ProviderContainer create() => ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );

    final first = create();
    expect(first.read(themeModeViewModelProvider), ThemeMode.system);
    await first
        .read(themeModeViewModelProvider.notifier)
        .setMode(ThemeMode.dark);
    first.dispose();

    final second = create();
    addTearDown(second.dispose);
    expect(second.read(themeModeViewModelProvider), ThemeMode.dark);
  });
}
