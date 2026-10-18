import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';

/// Strength of one vibration pulse.
enum HapticStrength { light, medium, heavy }

/// Vibration feedback. Features use this instead of calling the platform.
///
/// Android routes these through the system haptic feedback, so they follow
/// the phone's "touch vibration" setting.
abstract interface class IHapticService {
  Future<void> pulse(HapticStrength strength);

  /// A strong, unmistakable pattern (three heavy pulses and a long buzz)
  /// meant to be felt with the phone in a pocket.
  Future<void> alertPattern();
}

class HapticServiceImpl implements IHapticService {
  HapticServiceImpl(this._logger);

  final AppLogger _logger;

  static const Duration _patternGap = Duration(milliseconds: 160);

  @override
  Future<void> pulse(HapticStrength strength) async {
    try {
      switch (strength) {
        case HapticStrength.light:
          await HapticFeedback.lightImpact();
        case HapticStrength.medium:
          await HapticFeedback.mediumImpact();
        case HapticStrength.heavy:
          await HapticFeedback.heavyImpact();
      }
    } catch (e, st) {
      _logger.warning('Haptic pulse failed', e, st);
    }
  }

  @override
  Future<void> alertPattern() async {
    try {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(_patternGap);
      }
      await HapticFeedback.vibrate();
    } catch (e, st) {
      _logger.warning('Haptic alert pattern failed', e, st);
    }
  }
}

final hapticServiceProvider = Provider<IHapticService>(
  (ref) => HapticServiceImpl(ref.watch(appLoggerProvider)),
);
