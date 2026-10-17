import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Geiger-counter style buzzer: clicks (with a light haptic) at an interval
/// that shortens as the target gets closer. Silent beyond 6 m.
class GeigerBuzzerService {
  GeigerBuzzerService._();
  static final GeigerBuzzerService instance = GeigerBuzzerService._();

  Timer? _beepTimer;
  Duration _interval = const Duration(seconds: 1);
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  void toggleAudio(bool enabled) {
    _isEnabled = enabled;
    if (!_isEnabled) {
      stopBuzzer();
    }
  }

  /// Updates Geiger pulse frequency based on target distance in meters
  void updateTargetDistance(double distanceMeters) {
    if (!_isEnabled) return;

    if (distanceMeters <= 0 || distanceMeters > 6.0) {
      stopBuzzer();
      return;
    }

    // Interval = distance / 5 m × 880 ms + 120 ms, clamped to 120–1000 ms:
    // 0 m => 120 ms, 1 m => ~296 ms, 2 m => ~472 ms,
    // 3.5 m => ~736 ms, 5 m and beyond (up to 6 m) => 1000 ms.
    final intervalMs = ((distanceMeters / 5.0) * 880 + 120)
        .clamp(120, 1000)
        .toInt();

    _interval = Duration(milliseconds: intervalMs);
    // Callers update many times per second; restarting the timer on each
    // update would starve it, so a running loop just picks up the new rate.
    _beepTimer ??= Timer(_interval, _beep);
  }

  void _beep() {
    if (!_isEnabled) {
      _beepTimer = null;
      return;
    }
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
    _beepTimer = Timer(_interval, _beep);
  }

  void stopBuzzer() {
    _beepTimer?.cancel();
    _beepTimer = null;
  }
}

final geigerBuzzerProvider = Provider<GeigerBuzzerService>((ref) {
  final buzzer = GeigerBuzzerService.instance;
  ref.onDispose(buzzer.stopBuzzer);
  return buzzer;
});
