import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';

/// [IWakelockService] backed by `wakelock_plus`. Platform calls run one at a
/// time and always apply the latest wanted state, so fast enable/disable
/// sequences cannot leave the screen in the wrong state.
class WakelockServiceImpl implements IWakelockService {
  WakelockServiceImpl(this._logger, {Future<void> Function(bool on)? toggle})
    : _toggle = toggle ?? _platformToggle;

  final AppLogger _logger;
  final Future<void> Function(bool on) _toggle;
  final Set<String> _owners = {};
  Future<void> _queue = Future.value();
  bool? _applied;

  static Future<void> _platformToggle(bool on) =>
      WakelockPlus.toggle(enable: on);

  @override
  bool get isEnabled => _owners.isNotEmpty;

  @override
  Future<void> enable(String owner) {
    _owners.add(owner);
    return _apply();
  }

  @override
  Future<void> disable(String owner) {
    _owners.remove(owner);
    return _apply();
  }

  Future<void> _apply() {
    _queue = _queue.then((_) async {
      final wanted = _owners.isNotEmpty;
      if (_applied == wanted) return;
      try {
        await _toggle(wanted);
        _applied = wanted;
      } catch (e, st) {
        // Not fatal: the screen may just turn off by itself.
        _logger.warning(
          'Could not ${wanted ? 'keep' : 'release'} the '
          'screen wake lock',
          e,
          st,
        );
      }
    });
    return _queue;
  }
}
