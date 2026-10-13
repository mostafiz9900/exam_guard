import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Geiger Counter Audio Buzzer Service
/// Emits audio pulses with frequency accelerating as inspector gets closer to threat (< 1.5m).
class GeigerBuzzerService {
  GeigerBuzzerService._();
  static final GeigerBuzzerService instance = GeigerBuzzerService._();

  Timer? _beepTimer;
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

    // Compute interval in milliseconds:
    // Distance <= 1.0m  => 120ms (Rapid Geiger Beeping)
    // Distance ~ 1.8m   => 250ms
    // Distance ~ 3.5m   => 600ms
    // Distance ~ 5.0m   => 1000ms
    final intervalMs = ((distanceMeters / 5.0) * 880 + 120)
        .clamp(120, 1000)
        .toInt();

    _startGeigerLoop(Duration(milliseconds: intervalMs));
  }

  void _startGeigerLoop(Duration interval) {
    _beepTimer?.cancel();
    _beepTimer = Timer.periodic(interval, (_) {
      if (_isEnabled) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
      }
    });
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
