import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';

/// UI preferences are kept in one place so every screen responds consistently.
/// The chosen mode is saved in [ILocalStorage] so it survives a restart.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  static const storageKey = 'theme_mode';

  ILocalStorage? _storage;

  @override
  ThemeMode build() {
    try {
      _storage = ref.watch(localStorageProvider);
    } catch (e, st) {
      // Storage is not available (e.g. a test without an override):
      // the theme still works, it just isn't remembered.
      _storage = null;
      ref
          .read(appLoggerProvider)
          .warning('Theme preference storage unavailable', e, st);
      return ThemeMode.system;
    }
    final saved = _storage!.read<String>(storageKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage?.write(storageKey, mode.name);
    } catch (e, st) {
      ref
          .read(appLoggerProvider)
          .error('Saving theme preference failed', e, st);
    }
  }
}

final themeModeViewModelProvider =
    NotifierProvider<ThemeModeViewModel, ThemeMode>(ThemeModeViewModel.new);
