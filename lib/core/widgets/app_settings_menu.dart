import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../settings/app_settings.dart';

class AppSettingsMenu extends ConsumerWidget {
  const AppSettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'appearance'.tr(),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.system:
            ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
          case _MenuAction.light:
            ref.read(themeModeProvider.notifier).setMode(ThemeMode.light);
          case _MenuAction.dark:
            ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
          case _MenuAction.english:
            context.setLocale(const Locale('en'));
          case _MenuAction.bangla:
            context.setLocale(const Locale('bn'));
          case _MenuAction.arabic:
            context.setLocale(const Locale('ar'));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text('theme'.tr())),
        PopupMenuItem(
          value: _MenuAction.system,
          child: Text('system_theme'.tr()),
        ),
        PopupMenuItem(
          value: _MenuAction.light,
          child: Text('light_theme'.tr()),
        ),
        PopupMenuItem(value: _MenuAction.dark, child: Text('dark_theme'.tr())),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text('language'.tr())),
        PopupMenuItem(value: _MenuAction.english, child: Text('english'.tr())),
        PopupMenuItem(value: _MenuAction.bangla, child: Text('bangla'.tr())),
        PopupMenuItem(value: _MenuAction.arabic, child: Text('arabic'.tr())),
      ],
      icon: const Icon(Icons.tune),
    );
  }
}

enum _MenuAction { system, light, dark, english, bangla, arabic }
