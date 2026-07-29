import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// UI preferences are kept in one place so every screen responds consistently.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
