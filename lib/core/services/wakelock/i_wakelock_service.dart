import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wakelock/wakelock_service_impl.dart';

/// Keeps the screen on. Features use this instead of `wakelock_plus`.
///
/// Owner-counted like the Bluetooth scan: each screen that needs the
/// display on calls [enable] with its own owner key and [disable] when it
/// closes. The screen stays on while at least one owner is active, so one
/// screen closing never turns it off under another.
abstract interface class IWakelockService {
  Future<void> enable(String owner);

  Future<void> disable(String owner);

  /// True while at least one owner keeps the screen on.
  bool get isEnabled;
}

final wakelockServiceProvider = Provider<IWakelockService>(
  (ref) => WakelockServiceImpl(ref.watch(appLoggerProvider)),
);
