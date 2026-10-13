import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/sensors/magnetometer_service_impl.dart';

/// One magnetometer sample in microtesla (μT).
class MagnetometerReading {
  const MagnetometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime timestamp;
}

/// Live magnetometer access. Features use this instead of `sensors_plus`.
abstract interface class IMagnetometerService {
  /// Emits samples at roughly 50 Hz while listened to.
  Stream<MagnetometerReading> readings();
}

final magnetometerServiceProvider = Provider<IMagnetometerService>(
  (ref) => MagnetometerServiceImpl(),
);
