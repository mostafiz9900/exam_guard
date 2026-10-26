import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/classic_bluetooth/classic_bluetooth_service_impl.dart';
import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('exam_guard/classic_bt');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late int listens;
  late int cancels;
  // Whether the fake inquiry reports ACTION_DISCOVERY_FINISHED right away.
  late bool finishImmediately;

  setUp(() {
    listens = 0;
    cancels = 0;
    finishImmediately = true;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          listens++;
          sink.success({
            'type': 'found',
            'address': 'aa:bb:cc:dd:ee:ff',
            'name': ' Neckloop ',
            'rssi': -61,
            'majorDeviceClass': 0x0400,
            'deviceClass': 0x0404,
          });
          // A BLE-style malformed event is ignored.
          sink.success({'type': 'found', 'address': ''});
          if (finishImmediately) {
            sink.success({'type': 'finished', 'reason': 'done'});
          }
        },
        onCancel: (args) => cancels++,
      ),
    );
  });

  tearDown(() => messenger.setMockStreamHandler(channel, null));

  ClassicBluetoothServiceImpl build({bool isAndroid = true}) =>
      ClassicBluetoothServiceImpl(
        AppLogger(),
        isAndroid: isAndroid,
        pause: const Duration(milliseconds: 30),
        cycleTimeout: const Duration(seconds: 5),
      );

  Future<void> pump([int ms = 10]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('maps native records (upper-case address, trimmed name)', () async {
    final service = build();
    final first = service.discoveries.first;
    await service.start('a');
    final ClassicBtRecord r = await first;
    expect(r.address, 'AA:BB:CC:DD:EE:FF');
    expect(r.name, 'Neckloop');
    expect(r.rssi, -61);
    expect(r.majorDeviceClass, 0x0400);
    expect(r.deviceClass, 0x0404);
    await service.dispose();
  });

  test('repeats discovery cycles with a pause while an owner exists', () async {
    final service = build();
    await service.start('a');
    await pump(5);
    expect(listens, 1);
    await pump(150);
    expect(listens, greaterThan(2));
    // Each finished cycle cancels its subscription.
    expect(cancels, greaterThanOrEqualTo(listens - 1));
    await service.stop('a');
    final after = listens;
    await pump(120);
    expect(listens, after);
    await service.dispose();
  });

  test('keeps running until the last owner stops', () async {
    final service = build();
    await service.start('scanner');
    await service.start('radar');
    await service.stop('scanner');
    final before = listens;
    await pump(150);
    expect(listens, greaterThan(before));
    await service.stop('radar');
    final after = listens;
    await pump(120);
    expect(listens, after);
    await service.dispose();
  });

  test('stopping cancels an inquiry in progress', () async {
    finishImmediately = false;
    final service = build();
    await service.start('a');
    await pump();
    expect(listens, 1);
    expect(cancels, 0);
    final sw = Stopwatch()..start();
    await service.stop('a');
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    expect(cancels, 1);
    await service.dispose();
  });

  test('start/stop in quick succession is serialized', () async {
    final service = build();
    unawaited(service.start('a'));
    unawaited(service.stop('a'));
    unawaited(service.start('a'));
    await service.stop('a');
    final after = listens;
    await pump(120);
    expect(listens, after);
    expect(listens, lessThanOrEqualTo(2));
    await service.dispose();
  });

  test(
    'a finder pause cancels the inquiry and blocks cycles until resumed',
    () async {
      finishImmediately = false;
      final service = build();
      await service.start('scanner');
      await pump();
      expect(listens, 1);

      await service.suspend('walk_finder');
      expect(cancels, 1);
      final paused = listens;
      await pump(120);
      expect(listens, paused);

      await service.resume('walk_finder');
      await pump();
      expect(listens, greaterThan(paused));
      await service.stop('scanner');
      await service.dispose();
    },
  );

  test('does nothing where unsupported', () async {
    final service = build(isAndroid: false);
    expect(service.isSupported, isFalse);
    await service.start('a');
    await pump(60);
    expect(listens, 0);
    await service.dispose();
  });
}
