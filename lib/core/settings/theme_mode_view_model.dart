import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// UI preferences are kept in one place so every screen responds consistently.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) => state = mode;
}

final themeModeViewModelProvider =
    NotifierProvider<ThemeModeViewModel, ThemeMode>(ThemeModeViewModel.new);
