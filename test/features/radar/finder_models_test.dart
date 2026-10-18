import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/features/radar/model/proximity_meter.dart';
import 'package:exam_guard/features/radar/model/seat_sweep_models.dart';
import 'package:exam_guard/features/radar/model/walk_finder_models.dart';

void main() {
  group('closeness', () {
    test('maps -95 dBm → 0 % and -45 dBm → 100 %, clamped, linear', () {
      expect(ProximityMeter.closenessPercent(-95), 0);
      expect(ProximityMeter.closenessPercent(-45), 100);
      expect(ProximityMeter.closenessPercent(-70), 50);
      expect(ProximityMeter.closenessPercent(-120), 0);
      expect(ProximityMeter.closenessPercent(-20), 100);
      expect(ProximityMeter.closenessPercent(-60), 70);
    });
  });

  group('PeakHold', () {
    test('keeps the highest value until reset', () {
      final peak = PeakHold();
      expect(peak.percent, isNull);
      expect(peak.add(40, -75), isTrue);
      expect(peak.add(70, -60), isTrue);
      expect(peak.add(55, -67.5), isFalse);
      expect(peak.percent, 70);
      expect(peak.rssi, -60);
      peak.reset();
      expect(peak.percent, isNull);
      expect(peak.rssi, isNull);
      expect(peak.add(20, -85), isTrue);
      expect(peak.percent, 20);
    });
  });

  group('haptics', () {
    test('band strength rises with closeness', () {
      expect(HapticBand.fromCloseness(10), HapticBand.none);
      expect(HapticBand.fromCloseness(30).strength, HapticStrength.light);
      expect(HapticBand.fromCloseness(60).strength, HapticStrength.medium);
      expect(HapticBand.fromCloseness(90).strength, HapticStrength.heavy);
    });

    test('pulses are rate-limited per band', () {
      final limiter = HapticPulseLimiter();
      final t0 = DateTime(2026);
      var pulses = 0;
      // 10 packets/s for 2 s at heavy closeness → one pulse per 400 ms.
      for (var i = 0; i < 20; i++) {
        if (limiter.next(90, t0.add(Duration(milliseconds: 100 * i))) != null) {
          pulses++;
        }
      }
      expect(pulses, 5);
      expect(limiter.next(10, t0.add(const Duration(seconds: 10))), isNull);
    });
  });

  group('ZoneAlarm', () {
    final t0 = DateTime(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('alerts once on entering, not while staying inside', () {
      final alarm = ZoneAlarm();
      expect(alarm.update(-70, -60, at(0)), isFalse);
      expect(alarm.update(-58, -60, at(100)), isTrue);
      for (var i = 2; i < 30; i++) {
        expect(alarm.update(-55, -60, at(100 * i)), isFalse);
      }
      expect(alarm.isInside, isTrue);
    });

    test('no re-alert when leaving and re-entering within 5 s', () {
      final alarm = ZoneAlarm();
      expect(alarm.update(-58, -60, at(0)), isTrue);
      expect(alarm.update(-66, -60, at(1000)), isFalse); // left
      expect(alarm.isInside, isFalse);
      expect(alarm.update(-58, -60, at(4000)), isFalse); // back after 3 s
      expect(alarm.isInside, isTrue);
    });

    test('re-alerts after being outside for more than 5 s', () {
      final alarm = ZoneAlarm();
      expect(alarm.update(-58, -60, at(0)), isTrue);
      expect(alarm.update(-70, -60, at(1000)), isFalse); // left
      expect(alarm.update(-70, -60, at(4000)), isFalse);
      expect(alarm.update(-58, -60, at(6500)), isTrue); // 5.5 s outside
    });

    test('noise just under the threshold does not count as leaving', () {
      final alarm = ZoneAlarm();
      expect(alarm.update(-59, -60, at(0)), isTrue);
      // Dips to -62 (within the 3 dB hysteresis) for 10 s.
      for (var i = 1; i <= 100; i++) {
        expect(alarm.update(i.isEven ? -62 : -59, -60, at(100 * i)), isFalse);
      }
      expect(alarm.isInside, isTrue);
    });

    test('a lost target counts as outside since it was last heard', () {
      final alarm = ZoneAlarm();
      expect(alarm.update(-50, -60, at(0)), isTrue);
      alarm.markLost(at(0));
      expect(alarm.isInside, isFalse);
      expect(alarm.update(-50, -60, at(7000)), isTrue);
    });
  });

  group('WalkSensitivity', () {
    test('thresholds get lower (more sensitive) for larger distances', () {
      expect(WalkSensitivity.defaultValue.thresholdDbm, -60);
      expect(
        WalkSensitivity.close.thresholdDbm,
        greaterThan(WalkSensitivity.near.thresholdDbm),
      );
      expect(
        WalkSensitivity.near.thresholdDbm,
        greaterThan(WalkSensitivity.room.thresholdDbm),
      );
      expect(WalkSensitivity.values.map((s) => s.approxMeters), [1, 2, 4]);
    });
  });

  group('SeatSampler', () {
    test('needs at least 3 packets', () {
      final sampler = SeatSampler()..start();
      sampler.add(-60);
      sampler.add(-62);
      final reading = sampler.finish();
      expect(reading.hasSignal, isFalse);
      expect(reading.packets, 2);
    });

    test('averages the samples', () {
      final sampler = SeatSampler()..start();
      for (final v in [-60.0, -62.0, -64.0, -58.0]) {
        sampler.add(v);
      }
      final reading = sampler.finish();
      expect(reading.averageRssi, -61);
      expect(reading.packets, 4);
      sampler.start();
      expect(sampler.packets, 0);
    });
  });

  group('SeatSweepResult', () {
    SeatReading r(double? rssi) =>
        SeatReading(averageRssi: rssi, packets: rssi == null ? 1 : 10);

    test('no signal anywhere → no result', () {
      expect(SeatSweepResult.analyze({}), isNull);
      expect(SeatSweepResult.analyze({'A1': r(null)}), isNull);
    });

    test('picks the strongest seat and ignores no-signal seats', () {
      final result = SeatSweepResult.analyze({
        'A1': r(-70),
        'C4': r(-52),
        'C5': r(-60),
        'B2': r(null),
      })!;
      expect(result.bestSeat, 'C4');
      expect(result.bestRssi, -52);
      expect(result.secondSeat, 'C5');
      expect(result.marginDb, 8);
      expect(result.confidence, SweepConfidence.high);
      expect(result.seatsWithSignal, 3);
    });

    test('confidence from the margin to the runner-up', () {
      expect(SweepConfidence.fromMargin(6), SweepConfidence.high);
      expect(SweepConfidence.fromMargin(5.9), SweepConfidence.medium);
      expect(SweepConfidence.fromMargin(3), SweepConfidence.medium);
      expect(SweepConfidence.fromMargin(2.9), SweepConfidence.low);
      expect(SweepConfidence.fromMargin(null), SweepConfidence.low);
      expect(
        SeatSweepResult.analyze({'A1': r(-55)})!.confidence,
        SweepConfidence.low,
      );
    });
  });
}
