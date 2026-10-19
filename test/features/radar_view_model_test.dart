import 'dart:async';
import 'dart:math' as math;

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/view_model/rssi_trend_filter.dart';
import 'package:exam_guard/features/radar/view_model/tracking_radar_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'radar/finder_fakes.dart' show FakeHaptics, FakeScanner, FakeWakelock;

class FakeBluetoothService implements IBluetoothService {
  final records = StreamController<BleScanRecord>.broadcast();
  final owners = <String>{};
  BleScanException? startError;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() => Stream.value(BleAdapterStatus.on);

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  final problems = StreamController<BleScanError?>.broadcast();

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {
    if (startError != null) throw startError!;
    owners.add(owner);
  }

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      throw Exception('not supported');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async => records.close();
}

BleScanRecord record(String id, int rssi) => BleScanRecord(
  id: id,
  name: 'Phone',
  rssi: rssi,
  txPower: null,
  isConnectable: true,
  serviceUuids: const [],
  manufacturerData: const {},
  timestamp: DateTime.now(),
);

ScannedDeviceModel target({int rssi = -45, int? txPower}) => ScannedDeviceModel(
  id: 'AA:BB',
  name: 'Phone',
  rssi: rssi,
  txPower: txPower,
  lastSeen: DateTime.now().subtract(const Duration(seconds: 30)),
  firstSeen: DateTime.now().subtract(const Duration(minutes: 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RssiTrendFilter', () {
    test('trend stays stable under ±4 dB noise on a still target', () {
      final filter = RssiTrendFilter();
      final random = math.Random(42);
      final start = DateTime(2026);
      var changes = 0;
      var previous = filter.trend;
      // 30 s of packets at 10 Hz.
      for (var i = 0; i < 300; i++) {
        final noise = random.nextInt(9) - 4; // -4 … +4 dB
        filter.add(-70 + noise, start.add(Duration(milliseconds: 100 * i)));
        if (filter.trend != previous) changes++;
        previous = filter.trend;
      }
      expect(changes, lessThanOrEqualTo(2));
    });

    test('raw single-packet jumps do not flip the trend', () {
      final filter = RssiTrendFilter();
      final start = DateTime(2026);
      for (var i = 0; i < 100; i++) {
        final rssi = i.isEven ? -66 : -74; // ±4 dB every packet
        filter.add(rssi, start.add(Duration(milliseconds: 100 * i)));
        expect(filter.trend, ProximityTrend.stationary);
      }
    });

    test('a real approach is detected', () {
      final filter = RssiTrendFilter();
      final start = DateTime(2026);
      // -85 → -60 dBm over 5 s.
      for (var i = 0; i <= 50; i++) {
        filter.add(-85 + i ~/ 2, start.add(Duration(milliseconds: 100 * i)));
      }
      expect(filter.trend, ProximityTrend.approaching);
    });

    test('hysteresis keeps a trend until the change falls below exit', () {
      var trend = RssiTrendFilter.nextTrend(ProximityTrend.stationary, 3.2);
      expect(trend, ProximityTrend.approaching);
      trend = RssiTrendFilter.nextTrend(trend, 2.0);
      expect(trend, ProximityTrend.approaching);
      trend = RssiTrendFilter.nextTrend(trend, 1.0);
      expect(trend, ProximityTrend.stationary);
      expect(
        RssiTrendFilter.nextTrend(ProximityTrend.stationary, 2.5),
        ProximityTrend.stationary,
      );
    });
  });

  group('distance and threat', () {
    test('threat level always matches the computed distance', () {
      for (var rssi = -30; rssi >= -100; rssi--) {
        final d = TrackingRadarState.calculateDistance(rssi.toDouble());
        final threat = ThreatLevel.fromDistance(d);
        if (d <= 1.5) {
          expect(threat, ThreatLevel.critical, reason: '$rssi dBm, $d m');
        } else if (d <= 3.5) {
          expect(threat, ThreatLevel.high, reason: '$rssi dBm, $d m');
        } else if (d <= 6) {
          expect(threat, ThreatLevel.medium, reason: '$rssi dBm, $d m');
        } else {
          expect(threat, ThreatLevel.low, reason: '$rssi dBm, $d m');
        }
      }
    });

    test('uses advertised TX power for the 1 m reference', () {
      expect(TrackingRadarState.rssiAt1m(null), -59);
      expect(TrackingRadarState.rssiAt1m(4), -37);
      expect(TrackingRadarState.rssiAt1m(99), -59); // implausible value
      final d = TrackingRadarState.calculateDistance(
        -37,
        rssiAt1m: TrackingRadarState.rssiAt1m(4),
      );
      expect(d, closeTo(1.0, 0.001));
    });

    test('distance is shown with one decimal at most', () {
      expect(TrackingRadarState.formatDistance(4.3712), '≈4.4 m');
      expect(TrackingRadarState.formatDistance(23), '>10 m');
      expect(TrackingRadarState.formatDistance(null), '--');
    });
  });

  group('TrackingRadarViewModel', () {
    late FakeBluetoothService bluetooth;
    late FakeWakelock wakelock;
    late FakeHaptics haptics;
    late FakeScanner scanner;
    late ProviderContainer container;

    ProviderContainer create() {
      final c = ProviderContainer(
        overrides: [
          bluetoothServiceProvider.overrideWithValue(bluetooth),
          wakelockServiceProvider.overrideWithValue(wakelock),
          hapticServiceProvider.overrideWithValue(haptics),
          scannerViewModelProvider.overrideWith(() => scanner),
        ],
      );
      c.listen(trackingRadarViewModelProvider, (_, _) {});
      return c;
    }

    setUp(() {
      bluetooth = FakeBluetoothService();
      wakelock = FakeWakelock();
      haptics = FakeHaptics();
      scanner = FakeScanner();
      container = create();
    });

    test('keeps the screen on while open, releases it on dispose', () {
      expect(wakelock.owners, {'tracking_radar'});
      container.dispose();
      expect(wakelock.owners, isEmpty);
      expect(wakelock.calls, [
        'enable:tracking_radar',
        'disable:tracking_radar',
      ]);
      container = create();
    });

    test('closeness, peak hold and reset', () async {
      final notifier = container.read(trackingRadarViewModelProvider.notifier);
      await notifier.setTargetDevice(target());
      final start = DateTime(2026);
      var state = container.read(trackingRadarViewModelProvider);
      expect(state.closeness, isNull);
      expect(state.peakCloseness, isNull);

      // Approaches to -50 dBm, then walks away to -80 dBm.
      for (var i = 0; i < 30; i++) {
        notifier.updateDeviceSignal(
          -50,
          start.add(Duration(milliseconds: 100 * i)),
        );
      }
      state = container.read(trackingRadarViewModelProvider);
      expect(state.closeness, 90);
      expect(state.peakCloseness, 90);
      for (var i = 30; i < 60; i++) {
        notifier.updateDeviceSignal(
          -80,
          start.add(Duration(milliseconds: 100 * i)),
        );
      }
      state = container.read(trackingRadarViewModelProvider);
      expect(state.closeness, 30);
      expect(state.peakCloseness, 90, reason: 'best so far is held');
      expect(state.peakRssi!.round(), -50);

      notifier.resetPeak();
      state = container.read(trackingRadarViewModelProvider);
      expect(state.peakCloseness, isNull);
      notifier.updateDeviceSignal(-80, start.add(const Duration(seconds: 7)));
      notifier.updateDeviceSignal(-80, start.add(const Duration(seconds: 8)));
      notifier.updateDeviceSignal(-80, start.add(const Duration(seconds: 9)));
      expect(container.read(trackingRadarViewModelProvider).peakCloseness, 30);
    });

    test(
      'vibrates harder when closer, rate-limited, and can be muted',
      () async {
        final notifier = container.read(
          trackingRadarViewModelProvider.notifier,
        );
        await notifier.setTargetDevice(target());
        for (var i = 0; i < 20; i++) {
          notifier.updateDeviceSignal(-48);
        }
        expect(haptics.pulses, [HapticStrength.heavy]);

        notifier.toggleVibration();
        haptics.pulses.clear();
        await Future<void>.delayed(const Duration(milliseconds: 450));
        notifier.updateDeviceSignal(-48);
        expect(haptics.pulses, isEmpty);
      },
    );

    tearDown(() => container.dispose());

    test('acquires instead of showing the stale scanner RSSI', () async {
      await container
          .read(trackingRadarViewModelProvider.notifier)
          .setTargetDevice(target(rssi: -40));
      var state = container.read(trackingRadarViewModelProvider);
      expect(state.isAcquiring, isTrue);
      expect(state.distanceMeters, isNull);
      expect(state.rssiHistory, isEmpty);

      bluetooth.records.add(record('AA:BB', -70));
      await pumpEventQueue();
      state = container.read(trackingRadarViewModelProvider);
      expect(state.hasLiveSignal, isTrue);
      expect(state.rssiHistory, [-70]);
      expect(
        state.threatLevel,
        ThreatLevel.fromDistance(state.distanceMeters!),
      );
    });

    test('scan start failure is shown as an error', () async {
      bluetooth.startError = const BleScanException('Bluetooth is off.');
      await container
          .read(trackingRadarViewModelProvider.notifier)
          .setTargetDevice(target());
      final state = container.read(trackingRadarViewModelProvider);
      expect(state.errorKey, 'radar_err_scan_failed');
      expect(state.hasLiveSignal, isFalse);
    });

    test(
      'Location off shows the location reason and clears by itself',
      () async {
        final notifier = container.read(
          trackingRadarViewModelProvider.notifier,
        );
        await notifier.setTargetDevice(target());
        bluetooth.records.add(record('AA:BB', -60));
        await pumpEventQueue();
        expect(
          container.read(trackingRadarViewModelProvider).hasLiveSignal,
          isTrue,
        );

        bluetooth.problems.add(BleScanError.locationOff);
        await pumpEventQueue();
        var state = container.read(trackingRadarViewModelProvider);
        expect(state.isLocationOff, isTrue);
        expect(state.errorKey, TrackingRadarViewModel.locationOffErrorKey);
        expect(state.hasLiveSignal, isFalse);
        expect(bluetooth.owners, contains('tracking_radar'));

        bluetooth.problems.add(null);
        await pumpEventQueue();
        state = container.read(trackingRadarViewModelProvider);
        expect(state.isLocationOff, isFalse);
        expect(state.errorKey, isNull);
        // Waits for a fresh packet instead of the pre-outage distance.
        expect(state.isAcquiring, isTrue);
        expect(state.distanceMeters, isNull);

        bluetooth.records.add(record('AA:BB', -62));
        await pumpEventQueue();
        expect(
          container.read(trackingRadarViewModelProvider).hasLiveSignal,
          isTrue,
        );
      },
    );

    test('scan stream errors are shown as an error', () async {
      await container
          .read(trackingRadarViewModelProvider.notifier)
          .setTargetDevice(target());
      bluetooth.records.addError(const BleScanException('Scan stopped.'));
      await pumpEventQueue();
      expect(
        container.read(trackingRadarViewModelProvider).errorKey,
        'radar_err_scan_failed',
      );
    });

    test('hears the target on a rotated address', () async {
      await container
          .read(trackingRadarViewModelProvider.notifier)
          .setTargetDevice(target());
      bluetooth.records.add(record('CC:DD', -50));
      await pumpEventQueue();
      expect(container.read(trackingRadarViewModelProvider).rssi, isNull);

      scanner.changeIdentity('AA:BB', {'AA:BB', 'CC:DD'});
      await pumpEventQueue();
      bluetooth.records.add(record('CC:DD', -50));
      await pumpEventQueue();
      final state = container.read(trackingRadarViewModelProvider);
      expect(state.rssi, -50);
      expect(state.hasLiveSignal, isTrue);
      expect(state.device!.id, 'AA:BB');
    });
  });
}
