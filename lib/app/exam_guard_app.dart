import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_router.dart';
import 'package:exam_guard/core/services/toast/app_toast.dart';
import 'package:exam_guard/core/settings/theme_mode_view_model.dart';
import 'package:exam_guard/core/theme/app_theme.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

class ExamGuardApp extends ConsumerWidget {
  const ExamGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreenSize(
      builder: (context) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'ExamGuard',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ref.watch(themeModeViewModelProvider),
        routerConfig: AppRouter.router,
        builder: AppToast.init(),
        localizationsDelegates: context.appLocalizationDelegates,
        supportedLocales: context.appSupportedLocales,
        locale: context.appLocale,
      ),
    );
  }
}
