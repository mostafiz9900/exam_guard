import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/app/exam_guard_app.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/services/storage/hive_storage_impl.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalization.init();
  final storage = await HiveStorageImpl.open();

  runApp(
    AppLocalization(
      child: ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(storage)],
        child: const ExamGuardApp(),
      ),
    ),
  );
}
