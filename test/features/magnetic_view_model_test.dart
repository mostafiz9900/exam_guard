import 'dart:async';

import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/view_model/magnetic_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeMagnetometer implements IMagnetometerService {
  final controller = StreamController<MagnetometerReading>.broadcast();

  void emit(double magnitude) => controller.add(
    MagnetometerReading(x: magnitude, y: 0, z: 0, timestamp: DateTime.now()),
  );

  @override
  Stream<MagnetometerReading> readings() => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calculateHazard', () {
    for (final sensitivity in MagneticSensitivity.values) {
      for (final baseline in [25.0, 45.0, 65.0, 80.0]) {
        test('${sensitivity.name} @ baseline $baseline: ordered and '
            'every level reachable', () {
          final t = sensitivity.threshold;
          MagneticHazardLevel at(double m) =>
              MagneticState.calculateHazard(m, baseline, sensitivity);

          expect(at(baseline), MagneticHazardLevel.normal);
          expect(at(baseline + 0.9 * t), MagneticHazardLevel.normal);
          expect(at(baseline + 1.5 * t), MagneticHazardLevel.elevated);
          expect(at(baseline + 3 * t), MagneticHazardLevel.critical);
          expect(at(baseline + 5 * t), MagneticHazardLevel.strongSource);
          if (baseline - 1.5 * t > 0) {
            expect(at(baseline - 1.5 * t), MagneticHazardLevel.elevated);
          }

          // Never decreases as the field rises above the baseline.
          var previous = MagneticHazardLevel.normal;
          for (var m = baseline; m < baseline + 300; m += 0.5) {
            final level = at(m);
            expect(level.index, greaterThanOrEqualTo(previous.index));
            previous = level;
          }
        });
      }
    }

    test('higher sensitivity means a lower threshold', () {
      expect(
        MagneticSensitivity.high.threshold,
        lessThan(MagneticSensitivity.medium.threshold),
      );
      expect(
        MagneticSensitivity.medium.threshold,
        lessThan(MagneticSensitivity.low.threshold),
      );
    });
  });

  group('MagneticViewModel', () {
    late FakeMagnetometer sensor;
    late ProviderContainer container;

    setUp(() async {
      sensor = FakeMagnetometer();
      container = ProviderContainer(
        overrides: [magnetometerServiceProvider.overrideWithValue(sensor)],
      );
      container.listen(magneticViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('calibration fails while there is no live reading', () {
      final notifier = container.read(magneticViewModelProvider.notifier);
      expect(notifier.calibrateBaseline(), isFalse);
      expect(
        container.read(magneticViewModelProvider).isBaselineCalibrated,
        isFalse,
      );
    });

    test('calibration fails when paused and succeeds when live', () async {
      final notifier = container.read(magneticViewModelProvider.notifier);
      sensor.emit(45);
      await pumpEventQueue();
      expect(container.read(magneticViewModelProvider).isLive, isTrue);

      notifier.stopScanning();
      expect(container.read(magneticViewModelProvider).isLive, isFalse);
      expect(notifier.calibrateBaseline(), isFalse);

      notifier.startScanning();
      sensor.emit(50);
      await pumpEventQueue();
      expect(notifier.calibrateBaseline(), isTrue);
      final state = container.read(magneticViewModelProvider);
      expect(state.baseline, 50);
      expect(state.isBaselineCalibrated, isTrue);
    });

    test('a short spike between UI publishes still sets the peak', () async {
      sensor.emit(45); // first reading → baseline, published immediately
      await pumpEventQueue();
      // A burst faster than the 100 ms UI rate, spike in the middle.
      sensor.emit(46);
      sensor.emit(140);
      sensor.emit(46);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final state = container.read(magneticViewModelProvider);
      expect(state.peakValue, 140);
      expect(state.peakHazard, MagneticHazardLevel.strongSource);
    });
  });
}
