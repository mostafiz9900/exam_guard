import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/wakelock/i_wakelock_service.dart';
import 'package:exam_guard/features/radar/model/seat_sweep_models.dart';
import 'package:exam_guard/features/radar/view_model/seat_sweep_view_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

import 'finder_fakes.dart';

class _FakeSession extends SessionViewModel {
  _FakeSession(this._session);

  final SessionModel? _session;

  @override
  SessionModel? build() => _session;
}

SessionModel session({int? rows, int? cols}) => SessionModel(
  id: 's1',
  instituteName: 'School',
  teacherName: 'T',
  roomNumber: '12',
  startTime: DateTime(2026),
  seatRows: rows,
  seatCols: cols,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFinderBluetooth bluetooth;
  late FakeWakelock wakelock;
  late ProviderContainer container;

  void create(SessionModel? s) {
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        wakelockServiceProvider.overrideWithValue(wakelock),
        hapticServiceProvider.overrideWithValue(FakeHaptics()),
        sessionViewModelProvider.overrideWith(() => _FakeSession(s)),
        seatSampleDurationProvider.overrideWithValue(
          const Duration(milliseconds: 300),
        ),
      ],
    );
    container.listen(seatSweepViewModelProvider, (_, _) {});
  }

  SeatSweepViewModel notifier() =>
      container.read(seatSweepViewModelProvider.notifier);
  SeatSweepState state() => container.read(seatSweepViewModelProvider);

  setUp(() {
    bluetooth = FakeFinderBluetooth();
    wakelock = FakeWakelock();
  });

  tearDown(() => container.dispose());

  final t0 = DateTime(2026, 1, 1, 9);
  var clockMs = 0;
  void packets(int rssi, int count) {
    for (var i = 0; i < count; i++) {
      clockMs += 100;
      notifier().onSignal(rssi, t0.add(Duration(milliseconds: clockMs)));
    }
  }

  test('without a seat layout nothing is scanned', () async {
    create(session());
    await notifier().setTarget(bleDevice('AA'));
    expect(state().hasLayout, isFalse);
    expect(bluetooth.owners, isEmpty);
  });

  test('scans with its own owner and keeps the screen on', () async {
    create(session(rows: 4, cols: 5));
    await notifier().setTarget(bleDevice('AA'));
    expect(state().rows, 4);
    expect(state().cols, 5);
    expect(bluetooth.owners, {'seat_sweep'});
    expect(wakelock.owners, {'seat_sweep'});
    container.dispose();
    expect(bluetooth.owners, isEmpty);
    expect(wakelock.owners, isEmpty);
    create(session(rows: 4, cols: 5));
  });

  test('fewer than 3 packets → "no signal here"', () async {
    create(session(rows: 4, cols: 5));
    await notifier().setTarget(bleDevice('AA'));
    notifier().sampleSeat('C4');
    expect(state().isSampling, isTrue);
    packets(-55, 2);
    notifier().finishSample();
    expect(state().isSampling, isFalse);
    expect(state().noSignalSeat, 'C4');
    expect(state().readings['C4']!.hasSignal, isFalse);
    expect(state().result, isNull);
  });

  test('samples per seat, finds the best seat and its confidence', () async {
    create(session(rows: 4, cols: 5));
    await notifier().setTarget(bleDevice('AA'));

    notifier().sampleSeat('C4');
    packets(-52, 10);
    notifier().finishSample();
    notifier().sampleSeat('C5');
    packets(-60, 10);
    notifier().finishSample();

    final c4 = state().readings['C4']!;
    expect(c4.packets, 10);
    expect(c4.averageRssi, closeTo(-52, 0.01));
    // The sample filter restarts per seat: C5 is not dragged up by C4.
    expect(state().readings['C5']!.averageRssi, closeTo(-60, 0.01));

    var result = state().result!;
    expect(result.bestSeat, 'C4');
    expect(result.confidence, SweepConfidence.high);
    expect(
      notifier().incidentNotes(),
      contains('strongest at C4 (-52 dBm, high confidence; 8.0 dB above C5'),
    );

    // A close neighbour lowers the confidence.
    notifier().sampleSeat('C3');
    packets(-54, 10);
    notifier().finishSample();
    result = state().result!;
    expect(result.bestSeat, 'C4');
    expect(result.confidence, SweepConfidence.low);

    // Re-sampling replaces the reading.
    notifier().sampleSeat('C3');
    packets(-49, 10);
    notifier().finishSample();
    expect(state().result!.bestSeat, 'C3');
    expect(state().result!.confidence, SweepConfidence.medium);

    notifier().clearSeat('C3');
    expect(state().result!.bestSeat, 'C4');
    notifier().clearAll();
    expect(state().readings, isEmpty);
  });

  test('the sample finishes by itself after the sample duration', () async {
    create(session(rows: 2, cols: 2));
    await notifier().setTarget(bleDevice('AA'));
    notifier().sampleSeat('A1');
    packets(-61, 5);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(state().isSampling, isFalse);
    expect(state().readings['A1']!.averageRssi, closeTo(-61, 0.01));
  });

  test('cannot sample while the scan is blocked', () async {
    create(session(rows: 2, cols: 2));
    await notifier().setTarget(bleDevice('AA'));
    bluetooth.problems.add(BleScanError.locationOff);
    await pumpEventQueue();
    notifier().sampleSeat('A1');
    expect(state().isSampling, isFalse);
  });
}
