import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/model/seat_sweep_models.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view_model/finder_scan_monitor.dart';
import 'package:exam_guard/features/radar/view_model/rssi_trend_filter.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// How long one seat is sampled.
final seatSampleDurationProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

@immutable
class SeatSweepState {
  const SeatSweepState({
    this.device,
    this.rows = 0,
    this.cols = 0,
    this.readings = const {},
    this.samplingSeat,
    this.samplingProgress = 0,
    this.samplingPackets = 0,
    this.liveRssi,
    this.lastHeard,
    this.noSignalSeat,
    this.issue,
  });

  final ScannedDeviceModel? device;

  /// Seat layout of the running exam; 0 when the session has none.
  final int rows;
  final int cols;

  /// Measured seats by seat id ("C4").
  final Map<String, SeatReading> readings;

  /// Seat being sampled right now, or null.
  final String? samplingSeat;

  /// 0..1 progress of the current sample.
  final double samplingProgress;
  final int samplingPackets;

  /// Smoothed RSSI of the target right now (any position).
  final double? liveRssi;
  final DateTime? lastHeard;

  /// The last sample got too few packets ("No signal here").
  final String? noSignalSeat;

  /// What stops the scan from hearing anything; null while it works.
  final FinderScanIssue? issue;

  bool get hasLayout => rows > 0 && cols > 0;
  bool get isSampling => samplingSeat != null;

  SeatSweepResult? get result => SeatSweepResult.analyze(readings);

  SeatSweepState copyWith({
    ScannedDeviceModel? device,
    int? rows,
    int? cols,
    Map<String, SeatReading>? readings,
    String? Function()? samplingSeat,
    double? samplingProgress,
    int? samplingPackets,
    double? Function()? liveRssi,
    DateTime? Function()? lastHeard,
    String? Function()? noSignalSeat,
    FinderScanIssue? Function()? issue,
  }) => SeatSweepState(
    device: device ?? this.device,
    rows: rows ?? this.rows,
    cols: cols ?? this.cols,
    readings: readings ?? this.readings,
    samplingSeat: samplingSeat != null ? samplingSeat() : this.samplingSeat,
    samplingProgress: samplingProgress ?? this.samplingProgress,
    samplingPackets: samplingPackets ?? this.samplingPackets,
    liveRssi: liveRssi != null ? liveRssi() : this.liveRssi,
    lastHeard: lastHeard != null ? lastHeard() : this.lastHeard,
    noSignalSeat: noSignalSeat != null ? noSignalSeat() : this.noSignalSeat,
    issue: issue != null ? issue() : this.issue,
  );

  @override
  bool operator ==(Object other) =>
      other is SeatSweepState &&
      other.device == device &&
      other.rows == rows &&
      other.cols == cols &&
      mapEquals(other.readings, readings) &&
      other.samplingSeat == samplingSeat &&
      other.samplingProgress == samplingProgress &&
      other.samplingPackets == samplingPackets &&
      other.liveRssi == liveRssi &&
      other.lastHeard == lastHeard &&
      other.noSignalSeat == noSignalSeat &&
      other.issue == issue;

  @override
  int get hashCode => Object.hash(
    device,
    rows,
    cols,
    Object.hashAllUnordered(readings.entries.map((e) => (e.key, e.value))),
    samplingSeat,
    samplingProgress,
    samplingPackets,
    liveRssi,
    lastHeard,
    noSignalSeat,
    issue,
  );
}

/// Seat sweep: the inspector stands at seats one by one; the app records
/// the target's average signal per seat and points at the strongest seat.
class SeatSweepViewModel extends Notifier<SeatSweepState> {
  static const Duration _progressStep = Duration(milliseconds: 100);

  late RadarRepository _repository;
  late AppLogger _logger;
  late FinderScanMonitor _monitor;
  late Duration _sampleDuration;

  final RssiTrendFilter _liveFilter = RssiTrendFilter();
  final RssiTrendFilter _sampleFilter = RssiTrendFilter();
  final SeatSampler _sampler = SeatSampler();
  StreamSubscription<RadarSignal>? _sub;
  Timer? _sampleTimer;
  DateTime? _sampleStartedAt;

  @override
  SeatSweepState build() {
    _repository = ref.watch(radarRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    _sampleDuration = ref.watch(seatSampleDurationProvider);
    _monitor = FinderScanMonitor(_repository, _logger, _onIssue);
    _repository.keepScreenOn(RadarRepository.seatSweepOwner);
    ref.onDispose(_dispose);
    // Read once: incidents logged during the sweep update the session and
    // must not wipe the measured seats.
    final session = ref.read(sessionViewModelProvider);
    final hasLayout = session?.hasSeatLayout ?? false;
    return SeatSweepState(
      rows: hasLayout ? session!.seatRows! : 0,
      cols: hasLayout ? session!.seatCols! : 0,
    );
  }

  /// Starts listening to [device]. Needs a seat layout and a BLE device.
  Future<void> setTarget(ScannedDeviceModel device) async {
    if (state.device?.id == device.id) return;
    _cancelSample();
    state = SeatSweepState(device: device, rows: state.rows, cols: state.cols);
    if (!state.hasLayout || !device.isBle) return;

    _liveFilter.reset();
    await _sub?.cancel();
    _sub = _repository
        .watchDevice(device.id)
        .listen(
          (s) => onSignal(s.rssi, s.timestamp),
          onError: (Object e, StackTrace st) {
            _logger.warning('Seat sweep scan error', e, st);
            if (ref.mounted) _monitor.setError(e);
          },
        );
    _monitor.start();
    try {
      await _repository.startTracking(owner: RadarRepository.seatSweepOwner);
    } catch (e, st) {
      _logger.warning('Seat sweep could not start scanning', e, st);
      if (ref.mounted) _monitor.setError(e);
    }
  }

  /// Samples the target for the sample duration at [seat] (re-sampling
  /// replaces the old reading). Ignored while another seat is sampling.
  void sampleSeat(String seat) {
    // While the scan is blocked nothing can arrive; a sample would wrongly
    // read "no signal here".
    if (state.device == null || state.isSampling || state.issue != null) {
      return;
    }
    _sampleFilter.reset();
    _sampler.start();
    _sampleStartedAt = DateTime.now();
    state = state.copyWith(
      samplingSeat: () => seat,
      samplingProgress: 0,
      samplingPackets: 0,
      noSignalSeat: () => null,
    );
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(_progressStep, (_) => _onSampleTick());
  }

  void cancelSampling() {
    _cancelSample();
    if (ref.mounted) {
      state = state.copyWith(samplingSeat: () => null, samplingProgress: 0);
    }
  }

  void clearSeat(String seat) {
    if (!state.readings.containsKey(seat)) return;
    state = state.copyWith(
      readings: Map.of(state.readings)..remove(seat),
      noSignalSeat: () => null,
    );
  }

  void clearAll() {
    _cancelSample();
    state = state.copyWith(
      readings: const {},
      samplingSeat: () => null,
      samplingProgress: 0,
      noSignalSeat: () => null,
    );
  }

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  /// Starts the scan again after a failure.
  Future<void> retry() async {
    if (state.device == null || !state.hasLayout) return;
    _monitor.clearError();
    try {
      await _repository.startTracking(owner: RadarRepository.seatSweepOwner);
    } catch (e, st) {
      _logger.warning('Seat sweep could not restart scanning', e, st);
      if (ref.mounted) _monitor.setError(e);
    }
  }

  Future<void> turnOnBluetooth() async {
    try {
      await _repository.turnOnBluetooth();
    } catch (e, st) {
      _logger.warning('Could not turn Bluetooth on', e, st);
    }
  }

  /// Evidence for the incident form (English: official record).
  String incidentNotes() {
    final result = state.result;
    final name = state.device?.displayName ?? 'unknown device';
    if (result == null) {
      return 'Seat sweep: $name — no seat with a usable signal.';
    }
    final buffer = StringBuffer(
      'Located by seat sweep: $name strongest at ${result.bestSeat} '
      '(${result.bestRssi.round()} dBm, ${result.confidence.name} confidence',
    );
    final second = result.secondSeat;
    if (second != null) {
      buffer.write(
        '; ${result.marginDb!.toStringAsFixed(1)} dB above $second '
        'at ${result.secondRssi!.round()} dBm',
      );
    }
    buffer.write(
      '; ${state.readings.length} seat(s) sampled). '
      'Signal strength only — approximate.',
    );
    return buffer.toString();
  }

  /// One advertisement of the target (public for tests).
  @visibleForTesting
  void onSignal(int rssi, DateTime at) {
    if (!ref.mounted || state.device == null) return;
    _monitor.clearError();
    _liveFilter.add(rssi, at);
    var packets = state.samplingPackets;
    if (state.isSampling) {
      _sampleFilter.add(rssi, at);
      _sampler.add(_sampleFilter.smoothed!);
      packets = _sampler.packets;
    }
    state = state.copyWith(
      liveRssi: () => _liveFilter.smoothed,
      lastHeard: () => at,
      samplingPackets: packets,
    );
  }

  void _onSampleTick() {
    final startedAt = _sampleStartedAt;
    final seat = state.samplingSeat;
    if (!ref.mounted || startedAt == null || seat == null) {
      _cancelSample();
      return;
    }
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _sampleDuration) {
      state = state.copyWith(
        samplingProgress:
            elapsed.inMicroseconds / _sampleDuration.inMicroseconds,
      );
      return;
    }
    finishSample();
  }

  /// Ends the current sample now and stores its reading (public for tests).
  @visibleForTesting
  void finishSample() {
    final seat = state.samplingSeat;
    _cancelSample();
    if (seat == null || !ref.mounted) return;
    final reading = _sampler.finish();
    state = state.copyWith(
      readings: {...state.readings, seat: reading},
      samplingSeat: () => null,
      samplingProgress: 0,
      noSignalSeat: () => reading.hasSignal ? null : seat,
    );
  }

  void _cancelSample() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _sampleStartedAt = null;
  }

  void _onIssue(FinderScanIssue? issue) {
    if (!ref.mounted) return;
    if (issue != null) _cancelSample();
    state = state.copyWith(
      issue: () => issue,
      samplingSeat: issue != null ? () => null : null,
      samplingProgress: issue != null ? 0 : null,
    );
  }

  void _dispose() {
    _cancelSample();
    _sub?.cancel();
    _monitor.stop();
    _repository.releaseScreen(RadarRepository.seatSweepOwner);
    _repository.stopTracking(owner: RadarRepository.seatSweepOwner).catchError((
      Object e,
      StackTrace st,
    ) {
      _logger.warning('Seat sweep could not stop scanning', e, st);
    });
  }
}

final seatSweepViewModelProvider =
    NotifierProvider.autoDispose<SeatSweepViewModel, SeatSweepState>(
      SeatSweepViewModel.new,
    );
