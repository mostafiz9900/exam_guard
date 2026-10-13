import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/status_toast.dart';
import 'package:exam_guard/core/services/local_storage/hive_storage_impl.dart';

/// Entry point for ExamGuard application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Disable google_fonts runtime fetching to avoid network errors in restricted environments.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Hive storage and provide the implementation to Riverpod.
  final storage = await HiveStorageImpl.create();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(storage)],
        child: const ExamGuardApp(),
      ),
    ),
  );
}

class ExamGuardApp extends ConsumerWidget {
  const ExamGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilPlusInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'ExamGuard',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ref.watch(themeModeProvider),
          routerConfig: AppRouter.router,
          builder: StatusToast.init(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}
