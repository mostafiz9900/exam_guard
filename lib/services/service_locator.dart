import 'package:get_it/get_it.dart';

import 'logger/ilogger.dart';
import 'logger/logger_impl.dart';
import 'storage/hive_storage_impl.dart';
import 'storage/ilocal_storage.dart';

/// Global service locator for background and non-UI dependencies.
final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  getIt.registerLazySingleton<ILogger>(() => LoggerImpl());

  final hiveStorage = HiveStorageImpl('exam_guard_box');
  await hiveStorage.init();
  getIt.registerSingleton<ILocalStorage>(hiveStorage);
}
