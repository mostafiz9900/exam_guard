import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/model/seat_sweep_models.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view_model/finder_aliases.dart';
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
    this.isNotHeard = false,
    this.layoutErrorKey,
    this.isSavingLayout = false,
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

  /// The target hasn't been heard for a while (or not at all yet) although
  /// the scan works: sampling seats would only read "no signal".
  final bool isNotHeard;

  /// Translation key (args: min, max) of the problem with the seat layout
  /// typed into the inline form; null when there is none.
  final String? layoutErrorKey;

  /// The seat layout is being saved to the exam.
  final bool isSavingLayout;

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
    bool? isNotHeard,
    String? Function()? layoutErrorKey,
    bool? isSavingLayout,
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
    isNotHeard: isNotHeard ?? this.isNotHeard,
    layoutErrorKey: layoutErrorKey != null
        ? layoutErrorKey()
        : this.layoutErrorKey,
    isSavingLayout: isSavingLayout ?? this.isSavingLayout,
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
      other.issue == issue &&
      other.isNotHeard == isNotHeard &&
      other.layoutErrorKey == layoutErrorKey &&
      other.isSavingLayout == isSavingLayout;

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
    isNotHeard,
    layoutErrorKey,
    isSavingLayout,
  );
}

/// Rows × columns typed into seat sweep's "Set seat layout" form.
@immutable
class SeatLayoutDraft {
  const SeatLayoutDraft._({this.rows, this.cols, this.errorKey});

  static const int min = 1;
  static const int max = 30;

  /// Both must be whole numbers from [min] to [max] (same rules as the
  /// exam setup form, except that the layout can't be left empty here).
  factory SeatLayoutDraft.parse(String rowsText, String colsText) {
    final r = rowsText.trim();
    final c = colsText.trim();
    if (r.isEmpty || c.isEmpty) {
      return const SeatLayoutDraft._(errorKey: 'setup_seat_err_both');
    }
    final rows = int.tryParse(r);
    final cols = int.tryParse(c);
    bool inRange(int? v) => v != null && v >= min && v <= max;
    if (!inRange(rows) || !inRange(cols)) {
      return const SeatLayoutDraft._(errorKey: 'setup_seat_err_range');
    }
    return SeatLayoutDraft._(rows: rows, cols: cols);
  }

  final int? rows;
  final int? cols;

  /// Translation key of the problem (args: min, max), or null when valid.
  final String? errorKey;

  bool get isValid => errorKey == null;
}

/// Seat sweep: the inspector stands at seats one by one; the app records
/// the target's average signal per seat and points at the strongest seat.
class SeatSweepViewModel extends Notifier<SeatSweepState> {
  static const Duration _progressStep = Duration(milliseconds: 100);

  /// Silence after which the target counts as "not heard right now".
  static const Duration notHeardAfter = Duration(seconds: 10);

  late RadarRepository _repository;
  late AppLogger _logger;
  late FinderScanMonitor _monitor;
  late Duration _sampleDuration;
  late FinderAliases _aliases;

  /// Addresses the target is heard on (see [FinderAliases]).
  Set<String> _targetIds = const {};

  /// When listening started and when the last packet arrived (wall clock).
  DateTime? _listeningSince;
  DateTime? _lastPacketAt;
  Timer? _heardTimer;

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
    _aliases = FinderAliases(ref, _logger)..watch(_refreshAliases);
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

  /// Starts listening to [device]. Needs a seat layout and a BLE device;
  /// without a layout it waits for [saveSeatLayout].
  Future<void> setTarget(ScannedDeviceModel device) async {
    if (state.device?.id == device.id) return;
    _cancelSample();
    state = SeatSweepState(device: device, rows: state.rows, cols: state.cols);
    if (!state.hasLayout || !device.isBle) return;
    await _startListening();
  }

  /// Saves the rows × columns typed into the inline form to the running
  /// exam, then starts the sweep. Returns false (with
  /// [SeatSweepState.layoutErrorKey] set) when invalid or not saved.
  Future<bool> saveSeatLayout(String rowsText, String colsText) async {
    if (state.isSavingLayout) return false;
    final draft = SeatLayoutDraft.parse(rowsText, colsText);
    if (!draft.isValid) {
      state = state.copyWith(layoutErrorKey: () => draft.errorKey);
      return false;
    }
    state = state.copyWith(isSavingLayout: true, layoutErrorKey: () => null);
    try {
      await ref
          .read(sessionViewModelProvider.notifier)
          .setSeatLayout(rows: draft.rows!, cols: draft.cols!);
    } catch (e, st) {
      _logger.warning('Seat layout not saved', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          isSavingLayout: false,
          layoutErrorKey: () => 'sweep_layout_save_failed',
        );
      }
      return false;
    }
    if (!ref.mounted) return true;
    state = state.copyWith(
      rows: draft.rows,
      cols: draft.cols,
      isSavingLayout: false,
    );
    final device = state.device;
    if (device != null && device.isBle && _sub == null) {
      await _startListening();
    }
    return true;
  }

  /// Seat layout input changed: the old error no longer applies.
  void clearLayoutError() {
    if (state.layoutErrorKey == null) return;
    state = state.copyWith(layoutErrorKey: () => null);
  }

  Future<void> _startListening() async {
    final device = state.device;
    if (device == null) return;
    _liveFilter.reset();
    _targetIds = _aliases.of(device.id);
    _listeningSince = DateTime.now();
    _lastPacketAt = null;
    _heardTimer?.cancel();
    _heardTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => checkHeard(),
    );
    await _sub?.cancel();
    _sub = _repository
        .watchAll()
        .where((s) => _targetIds.contains(s.deviceId))
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

  /// The scanner learned new addresses of the target (rotation, group).
  void _refreshAliases() {
    final device = state.device;
    if (!ref.mounted || device == null || _sub == null) return;
    _targetIds = _aliases.of(device.id);
  }

  /// Once a second: is the target still being heard? (public for tests)
  @visibleForTesting
  void checkHeard([DateTime? at]) {
    final since = _lastPacketAt ?? _listeningSince;
    if (!ref.mounted || since == null) return;
    final now = at ?? DateTime.now();
    final notHeard =
        state.issue == null && now.difference(since) >= notHeardAfter;
    if (notHeard != state.isNotHeard) {
      state = state.copyWith(isNotHeard: notHeard);
    }
  }

  /// Samples the target for the sample duration at [seat] (re-sampling
  /// replaces the old reading). Ignored while another seat is sampling.
  void sampleSeat(String seat) {
    // While the scan is blocked, or the target is silent everywhere,
    // nothing can arrive; a sample would wrongly read "no signal here".
    if (state.device == null ||
        state.isSampling ||
        state.issue != null ||
        state.isNotHeard) {
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
    _lastPacketAt = DateTime.now();
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
      isNotHeard: false,
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
    if (issue == null && state.issue != null) {
      // Nothing could be heard while blocked: count silence from now.
      _listeningSince = DateTime.now();
      _lastPacketAt = null;
    }
    state = state.copyWith(
      issue: () => issue,
      isNotHeard: issue != null ? false : null,
      samplingSeat: issue != null ? () => null : null,
      samplingProgress: issue != null ? 0 : null,
    );
  }

  void _dispose() {
    _cancelSample();
    _heardTimer?.cancel();
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
