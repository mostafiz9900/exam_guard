import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';

import 'package:exam_guard/core/settings/theme_mode_view_model.dart';

class AppSettingsMenu extends ConsumerWidget {
  const AppSettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'appearance'.tr(),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.system:
            ref
                .read(themeModeViewModelProvider.notifier)
                .setMode(ThemeMode.system);
          case _MenuAction.light:
            ref
                .read(themeModeViewModelProvider.notifier)
                .setMode(ThemeMode.light);
          case _MenuAction.dark:
            ref
                .read(themeModeViewModelProvider.notifier)
                .setMode(ThemeMode.dark);
          case _MenuAction.english:
            context.setAppLocale(AppLocalization.english);
          case _MenuAction.bangla:
            context.setAppLocale(AppLocalization.bangla);
          case _MenuAction.arabic:
            context.setAppLocale(AppLocalization.arabic);
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
