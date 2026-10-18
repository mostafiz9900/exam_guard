import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/model/walk_finder_models.dart';
import 'package:exam_guard/features/radar/view_model/walk_finder_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

import 'finder_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFinderBluetooth bluetooth;
  late FakeWakelock wakelock;
  late FakeHaptics haptics;
  late ProviderContainer container;

  WalkFinderViewModel notifier() =>
      container.read(walkFinderViewModelProvider.notifier);
  WalkFinderState state() => container.read(walkFinderViewModelProvider);

  setUp(() {
    bluetooth = FakeFinderBluetooth();
    wakelock = FakeWakelock();
    haptics = FakeHaptics();
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        wakelockServiceProvider.overrideWithValue(wakelock),
        hapticServiceProvider.overrideWithValue(haptics),
      ],
    );
    container.listen(walkFinderViewModelProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  final t0 = DateTime(2026, 1, 1, 9);

  /// Feeds [rssi] for [ms] milliseconds at 10 Hz starting at [fromMs].
  int feed(String id, int rssi, int fromMs, int ms) {
    for (var t = fromMs; t < fromMs + ms; t += 100) {
      notifier().onSignal(id, rssi, t0.add(Duration(milliseconds: t)));
    }
    return fromMs + ms;
  }

  test('keeps the screen on while open and releases it on dispose', () async {
    expect(wakelock.owners, {'walk_finder'});
    container.dispose();
    expect(wakelock.owners, isEmpty);
    expect(wakelock.calls.last, 'disable:walk_finder');
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        wakelockServiceProvider.overrideWithValue(wakelock),
        hapticServiceProvider.overrideWithValue(haptics),
      ],
    );
  });

  test('takes at most 5 BLE targets, without duplicates', () {
    notifier().setTargets([
      for (var i = 0; i < 6; i++) bleDevice('ID$i'),
      bleDevice('ID0'),
      bleDevice('C1', transport: DeviceTransport.classic),
    ]);
    expect(state().targets.map((t) => t.device.id), [
      'ID0',
      'ID1',
      'ID2',
      'ID3',
      'ID4',
    ]);
    expect(state().skippedNonBle, 3);
  });

  test(
    'alerts on entering the zone, no spam, re-alerts after > 5 s out',
    () async {
      notifier().setTargets([bleDevice('AA')]);
      await notifier().start();
      expect(bluetooth.owners, {'walk_finder'});

      var t = feed('AA', -75, 0, 2000);
      expect(state().alertCount, 0);
      expect(state().targets.single.isVeryClose, isFalse);

      t = feed('AA', -52, t, 3000); // walks up to it
      expect(state().alertCount, 1);
      expect(haptics.alerts, 1);
      expect(state().targets.single.isVeryClose, isTrue);
      expect(state().anyVeryClose, isTrue);

      // Steps away briefly and comes back within 5 s: no new alert.
      t = feed('AA', -80, t, 2000);
      expect(state().targets.single.isVeryClose, isFalse);
      t = feed('AA', -52, t, 2000);
      expect(state().alertCount, 1);

      // Away for 7 s, then back: alerts again.
      t = feed('AA', -80, t, 7000);
      feed('AA', -52, t, 2000);
      expect(state().alertCount, 2);
      expect(haptics.alerts, 2);
    },
  );

  test('sensitivity changes the alert threshold', () async {
    notifier().setTargets([bleDevice('AA')]);
    await notifier().start();
    var t = feed('AA', -70, 0, 3000);
    expect(state().alertCount, 0, reason: '-70 dBm is not within ≈1 m');

    notifier().setSensitivity(WalkSensitivity.room);
    t = feed('AA', -70, t, 1000);
    expect(state().alertCount, 1, reason: 'room threshold is -74 dBm');

    notifier().setSensitivity(WalkSensitivity.close);
    feed('AA', -70, t, 1000);
    expect(state().targets.single.isVeryClose, isFalse);
  });

  test('ignores packets while stopped and from other devices', () async {
    notifier().setTargets([bleDevice('AA')]);
    feed('AA', -40, 0, 2000);
    expect(state().targets.single.smoothedRssi, isNull);

    await notifier().start();
    bluetooth.records.add(bleRecord('BB', -40));
    bluetooth.records.add(bleRecord('AA', -66));
    await pumpEventQueue();
    expect(state().targets.single.smoothedRssi, -66);
    expect(state().targets.single.lastHeard, isNotNull);

    notifier().stop();
    expect(state().isRunning, isFalse);
    expect(bluetooth.owners, isEmpty);
  });

  test('a target that goes silent leaves the zone', () async {
    notifier().setTargets([bleDevice('AA')]);
    await notifier().start();
    feed('AA', -50, 0, 2000);
    expect(state().targets.single.isVeryClose, isTrue);
    notifier().tick(t0.add(const Duration(seconds: 10)));
    expect(state().targets.single.isVeryClose, isFalse);
  });

  test('shows why it cannot scan: Location off, Bluetooth off', () async {
    notifier().setTargets([bleDevice('AA')]);
    await notifier().start();
    expect(state().issue, isNull);

    bluetooth.problems.add(BleScanError.locationOff);
    await pumpEventQueue();
    expect(state().issue, FinderScanIssue.locationOff);

    bluetooth.adapter.add(BleAdapterStatus.off);
    await pumpEventQueue();
    expect(state().issue, FinderScanIssue.bluetoothOff);

    bluetooth.adapter.add(BleAdapterStatus.on);
    await pumpEventQueue();
    expect(state().issue, FinderScanIssue.locationOff);

    bluetooth.problems.add(null);
    await pumpEventQueue();
    expect(state().issue, isNull);
  });

  test('scan start failure is reported', () async {
    bluetooth.startError = const BleScanException(
      'busy',
      code: BleScanError.throttled,
    );
    notifier().setTargets([bleDevice('AA')]);
    await notifier().start();
    expect(state().issue, FinderScanIssue.throttled);
  });

  test('muting stops new alert sounds but keeps vibration', () async {
    notifier().setTargets([bleDevice('AA')]);
    await notifier().start();
    notifier().toggleSound();
    expect(state().isSoundEnabled, isFalse);
    feed('AA', -50, 0, 2000);
    expect(state().alertCount, 1);
    expect(haptics.alerts, 1);
  });
}
