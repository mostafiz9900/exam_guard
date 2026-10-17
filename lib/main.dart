import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/app/exam_guard_app.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/services/storage/hive_storage_impl.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
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

/// Bundled Noto fonts (used in PDF reports) are SIL OFL licensed.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['NotoSans', 'NotoSansBengali', 'NotoSansArabic']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
