import 'package:sensors_plus/sensors_plus.dart';

import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';

class MagnetometerServiceImpl implements IMagnetometerService {
  @override
  Stream<MagnetometerReading> readings() {
    return magnetometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).map(
      (e) =>
          MagnetometerReading(x: e.x, y: e.y, z: e.z, timestamp: e.timestamp),
    );
  }
}
