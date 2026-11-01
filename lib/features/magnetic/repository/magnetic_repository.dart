import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';

/// One magnetometer sample with its total field strength, in microtesla.
class MagneticSample {
  MagneticSample.fromAxes(
    this.x,
    this.y,
    this.z, {
    this.isCalibrated = true,
    this.accuracy = MagnetometerAccuracy.unknown,
  }) : magnitude = math.sqrt(x * x + y * y + z * z);

  final double x;
  final double y;
  final double z;
  final double magnitude;

  /// False for a raw reading with the phone's own bias in it.
  final bool isCalibrated;
  final MagnetometerAccuracy accuracy;
}

/// Live readings from the phone's magnetometer.
class MagneticRepository {
  MagneticRepository(this._sensor);

  final IMagnetometerService _sensor;

  Stream<MagneticSample> samples() => _sensor.readings().map(
    (r) => MagneticSample.fromAxes(
      r.x,
      r.y,
      r.z,
      isCalibrated: r.isCalibrated,
      accuracy: r.accuracy,
    ),
  );
}

final magneticRepositoryProvider = Provider<MagneticRepository>(
  (ref) => MagneticRepository(ref.watch(magnetometerServiceProvider)),
);
