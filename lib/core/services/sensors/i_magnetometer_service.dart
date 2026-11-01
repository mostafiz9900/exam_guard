import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/sensors/magnetometer_service_impl.dart';

/// How much the OS trusts its compass calibration.
enum MagnetometerAccuracy {
  /// Not reported (Android): treat as calibrated.
  unknown,

  /// The OS has no calibration yet: readings may be far off. Moving the
  /// phone in a figure-8 calibrates it.
  uncalibrated,
  low,
  medium,
  high;

  bool get needsCalibration => this == uncalibrated || this == low;
}

/// One magnetometer sample in microtesla (μT).
class MagnetometerReading {
  const MagnetometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
    this.isCalibrated = true,
    this.accuracy = MagnetometerAccuracy.unknown,
  });

  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  /// False for a raw reading that still contains the phone's own bias
  /// (absolute values are meaningless; only changes count).
  final bool isCalibrated;
  final MagnetometerAccuracy accuracy;
}

/// Live magnetometer access. Features use this instead of `sensors_plus`.
abstract interface class IMagnetometerService {
  /// Emits samples at roughly 50 Hz while listened to.
  Stream<MagnetometerReading> readings();
}

final magnetometerServiceProvider = Provider<IMagnetometerService>(
  (ref) => MagnetometerServiceImpl(),
);
