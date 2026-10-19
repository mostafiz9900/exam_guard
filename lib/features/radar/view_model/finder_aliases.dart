import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// The addresses a finder target is heard on right now.
///
/// Phones and earbuds advertise from several random addresses at once and
/// change them every few minutes, so listening to the one address the
/// inspector tapped often hears nothing. The scanner knows which addresses
/// belong together ([ScannerViewModel.aliasesOf]); this asks it and
/// reports when that knowledge changes. Watching also keeps the scanner
/// alive while a finder is open.
class FinderAliases {
  FinderAliases(this._ref, this._logger);

  final Ref _ref;
  final AppLogger _logger;

  /// Calls [onChange] whenever the scanner's identity knowledge changes.
  /// Call from the view model's `build` (the subscription ends with it).
  void watch(void Function() onChange) {
    try {
      _ref.listen<int>(
        scannerViewModelProvider.select((s) => s.identityVersion),
        (_, _) => onChange(),
        onError: (Object e, StackTrace st) =>
            _logger.warning('Finder: scanner identity unavailable', e, st),
      );
    } catch (e, st) {
      _logger.warning('Finder: scanner identity unavailable', e, st);
    }
  }

  /// Every address of [deviceId]'s device; just [deviceId] when the scanner
  /// can't tell.
  Set<String> of(String deviceId) {
    try {
      final aliases = _ref
          .read(scannerViewModelProvider.notifier)
          .aliasesOf(deviceId);
      return {...aliases, deviceId};
    } catch (e, st) {
      _logger.warning('Finder: aliases of $deviceId unavailable', e, st);
      return {deviceId};
    }
  }
}
