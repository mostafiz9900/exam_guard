// Why the magnetic scanner "didn't work properly", and the fixes:
// a glitchy first reading, iPhone raw-sensor bias, slow drift from moving
// the phone, and compass calibration.

import 'dart:async';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/core/services/sensors/magnetometer_service_impl.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Sensor implements IMagnetometerService {
  final controller = StreamController<MagnetometerReading>.broadcast();

  void emit(
    double magnitude, {
    bool calibrated = true,
    MagnetometerAccuracy accuracy = MagnetometerAccuracy.unknown,
  }) => controller.add(
    MagnetometerReading(
      x: magnitude,
      y: 0,
      z: 0,
      timestamp: DateTime.now(),
      isCalibrated: calibrated,
      accuracy: accuracy,
    ),
  );

  @override
  Stream<MagnetometerReading> readings() => controller.stream;
}

class _Buzzer implements GeigerBuzzerService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _Sensor sensor;
  late ProviderContainer c;
  MagneticState read() => c.read(magneticViewModelProvider);

  Future<void> feed(Iterable<double> values, {bool calibrated = true}) async {
    for (final v in values) {
      sensor.emit(v, calibrated: calibrated);
      await pumpEventQueue();
    }
    // Let the ~10 Hz UI publish happen.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  setUp(() async {
    MagneticViewModel.settleSamples = 5;
    sensor = _Sensor();
    c = ProviderContainer(
      overrides: [
        magnetometerServiceProvider.overrideWithValue(sensor),
        geigerBuzzerProvider.overrideWithValue(_Buzzer()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(magneticViewModelProvider, (_, _) {});
    await pumpEventQueue();
  });

  test('a glitchy first reading does not become the baseline', () async {
    // Warm-up spike first; the median of the first 5 is the real field.
    await feed([0, 46, 45, 44, 45]);
    expect(read().baseline, 45);
    await feed([46]);
    expect(read().hazardLevel, MagneticHazardLevel.normal);
  });

  test(
    'raw iPhone bias is not a "strong source"; calibrated 250 µT is',
    () async {
      // Raw sensor with ~400 µT of the phone's own bias, nothing nearby.
      await feed([452, 451, 452, 453, 452, 452], calibrated: false);
      expect(read().isRawSensor, isTrue);
      expect(read().hazardLevel, MagneticHazardLevel.normal);

      final sensor2 = _Sensor();
      final c2 = ProviderContainer(
        overrides: [
          magnetometerServiceProvider.overrideWithValue(sensor2),
          geigerBuzzerProvider.overrideWithValue(_Buzzer()),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(magneticViewModelProvider, (_, _) {});
      await pumpEventQueue();
      for (final v in const <double>[250, 250, 250, 250, 250, 250]) {
        sensor2.emit(v);
        await pumpEventQueue();
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        c2.read(magneticViewModelProvider).hazardLevel,
        MagneticHazardLevel.strongSource,
      );
    },
  );

  test('slow drift from moving the phone is followed, not alarmed', () async {
    await feed([45, 45, 45, 45, 45]);
    // Tilting / walking: the field creeps up 15 µT over ~6 s at 50 Hz —
    // more than the medium threshold (20) would allow without tracking.
    await feed([for (var i = 0; i < 300; i++) 45 + 15 * i / 300]);
    expect(read().hazardLevel, MagneticHazardLevel.normal);
    expect(read().baseline, greaterThan(50));
  });

  test(
    'a real magnet stays flagged — the baseline does not chase it',
    () async {
      await feed([45, 45, 45, 45, 45]);
      await feed([for (var i = 0; i < 300; i++) 95.0]);
      expect(read().hazardLevel, MagneticHazardLevel.critical);
      expect(read().baseline, closeTo(45, 0.5));
    },
  );

  test(
    'low compass accuracy asks for calibration; zero fields skipped',
    () async {
      for (var i = 0; i < 3; i++) {
        sensor.emit(
          0,
          calibrated: false,
          accuracy: MagnetometerAccuracy.uncalibrated,
        );
        await pumpEventQueue();
      }
      expect(read().needsCalibration, isTrue);
      expect(read().isLive, isFalse, reason: 'no usable reading yet');

      for (var i = 0; i < 6; i++) {
        sensor.emit(45, accuracy: MagnetometerAccuracy.low);
        await pumpEventQueue();
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(read().isLive, isTrue);
      expect(read().needsCalibration, isTrue);

      sensor.emit(45, accuracy: MagnetometerAccuracy.high);
      await pumpEventQueue();
      expect(read().needsCalibration, isFalse);
    },
  );

  test('a magnet that lowers the field counts as the biggest change', () async {
    await feed([45, 45, 45, 45, 45]);
    await feed([4]); // magnet opposing Earth's field
    expect(read().hazardLevel, MagneticHazardLevel.critical);
    expect(read().peakChange, 41);
    await feed([45]);
    expect(read().peakChange, 41, reason: 'the peak is remembered');
  });

  test('improving compass calibration measures the baseline again', () async {
    Future<void> emit(double v, MagnetometerAccuracy a) async {
      sensor.emit(v, accuracy: a);
      await pumpEventQueue();
    }

    for (var i = 0; i < 5; i++) {
      await emit(45, MagnetometerAccuracy.low);
    }
    // Core Motion settles its bias estimate: the field jumps, nothing moved.
    for (var i = 0; i < 5; i++) {
      await emit(80, MagnetometerAccuracy.high);
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(read().baseline, 80);
    expect(read().hazardLevel, MagneticHazardLevel.normal);
    expect(read().peakHazard, MagneticHazardLevel.normal);
  });

  test('uncalibrated accuracy never triggers the absolute rule', () async {
    for (var i = 0; i < 6; i++) {
      sensor.emit(400, accuracy: MagnetometerAccuracy.uncalibrated);
      await pumpEventQueue();
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(read().hazardLevel, MagneticHazardLevel.normal);
    expect(read().isRawSensor, isTrue);
  });

  test('resume measures an automatic baseline again, keeps Set zero', () async {
    final vm = c.read(magneticViewModelProvider.notifier);
    await feed([45, 45, 45, 45, 45]);
    vm.stopScanning();
    // Walked to another desk while paused.
    vm.startScanning();
    await feed([60, 60, 60, 60, 60]);
    expect(read().baseline, 60);
    expect(read().hazardLevel, MagneticHazardLevel.normal);

    expect(vm.calibrateBaseline(), isTrue);
    vm.stopScanning();
    vm.startScanning();
    await feed([110]);
    expect(read().baseline, 60);
    expect(read().hazardLevel, MagneticHazardLevel.critical);
  });

  group('native calibrated events', () {
    test('parse x, y, z and accuracy', () {
      final r = MagnetometerServiceImpl.parseCalibrated([
        3.0,
        4.0,
        0.0,
        2,
        1.5,
      ])!;
      expect((r.x, r.y, r.z), (3.0, 4.0, 0.0));
      expect(r.accuracy, MagnetometerAccuracy.high);
      expect(r.isCalibrated, isTrue);
    });

    test('an all-zero field means "not calibrated yet"', () {
      final r = MagnetometerServiceImpl.parseCalibrated([0, 0, 0, 1, 0])!;
      expect(r.isCalibrated, isFalse);
      expect(r.accuracy, MagnetometerAccuracy.uncalibrated);
    });

    test('junk is ignored', () {
      expect(MagnetometerServiceImpl.parseCalibrated('x'), isNull);
      expect(MagnetometerServiceImpl.parseCalibrated([1, 2]), isNull);
    });
  });
}
