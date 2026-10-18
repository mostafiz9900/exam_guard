import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wakelock/wakelock_service_impl.dart';

void main() {
  test('screen stays on while any owner holds it', () async {
    final applied = <bool>[];
    final service = WakelockServiceImpl(
      AppLogger(),
      toggle: (on) async => applied.add(on),
    );

    await service.enable('tracking_radar');
    await service.enable('seat_sweep');
    expect(service.isEnabled, isTrue);
    expect(applied, [true]);

    await service.disable('seat_sweep');
    expect(service.isEnabled, isTrue);
    expect(applied, [true], reason: 'radar is still open');

    await service.disable('tracking_radar');
    expect(service.isEnabled, isFalse);
    expect(applied, [true, false]);

    await service.disable('tracking_radar'); // unknown owner: no-op
    expect(applied, [true, false]);
  });

  test('platform errors are logged, not thrown', () async {
    final service = WakelockServiceImpl(
      AppLogger(),
      toggle: (_) async => throw Exception('no plugin'),
    );
    await service.enable('walk_finder');
    expect(service.isEnabled, isTrue);
  });
}
