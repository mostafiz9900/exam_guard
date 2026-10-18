import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/model/walk_finder_models.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view_model/finder_scan_monitor.dart';
import 'package:exam_guard/features/radar/view_model/rssi_trend_filter.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

@immutable
class WalkFinderState {
  const WalkFinderState({
    this.targets = const [],
    this.skippedNonBle = 0,
    this.isRunning = false,
    this.sensitivity = WalkSensitivity.defaultValue,
    this.isSoundEnabled = true,
    this.issue,
    this.alertCount = 0,
    required this.now,
  });

  final List<WalkTarget> targets;

  /// Chosen devices left out because they are not BLE (no live signal).
  final int skippedNonBle;
  final bool isRunning;
  final WalkSensitivity sensitivity;
  final bool isSoundEnabled;

  /// What stops the scan from hearing anything; null while it works.
  final FinderScanIssue? issue;

  /// Alerts fired since the last start.
  final int alertCount;

  /// Clock for "last heard"; ticks every second while running.
  final DateTime now;

  bool get anyVeryClose => targets.any((t) => t.isVeryClose);

  WalkFinderState copyWith({
    List<WalkTarget>? targets,
    int? skippedNonBle,
    bool? isRunning,
    WalkSensitivity? sensitivity,
    bool? isSoundEnabled,
    FinderScanIssue? Function()? issue,
    int? alertCount,
    DateTime? now,
  }) => WalkFinderState(
    targets: targets ?? this.targets,
    skippedNonBle: skippedNonBle ?? this.skippedNonBle,
    isRunning: isRunning ?? this.isRunning,
    sensitivity: sensitivity ?? this.sensitivity,
    isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
    issue: issue != null ? issue() : this.issue,
    alertCount: alertCount ?? this.alertCount,
    now: now ?? this.now,
  );

  @override
  bool operator ==(Object other) =>
      other is WalkFinderState &&
      listEquals(other.targets, targets) &&
      other.skippedNonBle == skippedNonBle &&
      other.isRunning == isRunning &&
      other.sensitivity == sensitivity &&
      other.isSoundEnabled == isSoundEnabled &&
      other.issue == issue &&
      other.alertCount == alertCount &&
      other.now == now;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(targets),
    skippedNonBle,
    isRunning,
    sensitivity,
    isSoundEnabled,
    issue,
    alertCount,
    now,
  );
}

/// Hands-free finder: the inspector walks the aisles with the phone in a
/// pocket; it vibrates and beeps when any chosen device is very close.
class WalkFinderViewModel extends Notifier<WalkFinderState> {
  static const int maxTargets = 5;

  late RadarRepository _repository;
  late GeigerBuzzerService _buzzer;
  late IHapticService _haptics;
  late AppLogger _logger;
  late FinderScanMonitor _monitor;

  final Map<String, RssiTrendFilter> _filters = {};
  final Map<String, ZoneAlarm> _alarms = {};
  StreamSubscription<RadarSignal>? _sub;
  Timer? _ticker;

  @override
  WalkFinderState build() {
    _repository = ref.watch(radarRepositoryProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    _haptics = ref.watch(hapticServiceProvider);
    _logger = ref.watch(appLoggerProvider);
    _monitor = FinderScanMonitor(_repository, _logger, _onIssue);
    _repository.keepScreenOn(RadarRepository.walkFinderOwner);
    ref.onDispose(_dispose);
    return WalkFinderState(now: DateTime.now());
  }

  /// Sets the devices to look for: BLE only (others have no live signal),
  /// duplicates removed, at most [maxTargets].
  void setTargets(List<ScannedDeviceModel> devices) {
    final seen = <String>{};
    final ble = [
      for (final d in devices)
        if (d.isBle && seen.add(d.id)) d,
    ];
    final chosen = ble.take(maxTargets).toList();
    if (state.isRunning) stop();
    _filters.clear();
    _alarms.clear();
    state = state.copyWith(
      targets: [for (final d in chosen) WalkTarget(device: d)],
      skippedNonBle: devices.length - chosen.length,
    );
  }

  Future<void> start() async {
    if (state.isRunning || state.targets.isEmpty) return;
    for (final t in state.targets) {
      _filters[t.device.id] = RssiTrendFilter();
      _alarms[t.device.id] = ZoneAlarm();
    }
    state = state.copyWith(
      isRunning: true,
      issue: () => null,
      alertCount: 0,
      now: DateTime.now(),
      targets: [for (final t in state.targets) WalkTarget(device: t.device)],
    );

    await _sub?.cancel();
    _sub = _repository
        .watchDevices({for (final t in state.targets) t.device.id})
        .listen(
          (s) => onSignal(s.deviceId, s.rssi, s.timestamp),
          onError: (Object e, StackTrace st) {
            _logger.warning('Walk finder scan error', e, st);
            if (ref.mounted) _monitor.setError(e);
          },
        );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    _monitor.start();

    try {
      await _repository.startTracking(owner: RadarRepository.walkFinderOwner);
    } catch (e, st) {
      _logger.warning('Walk finder could not start scanning', e, st);
      if (ref.mounted && state.isRunning) _monitor.setError(e);
    }
  }

  /// Stops scanning and any alert this screen started.
  void stop() {
    _stopScanning();
    if (!ref.mounted) return;
    state = state.copyWith(
      isRunning: false,
      issue: () => null,
      targets: [for (final t in state.targets) t.copyWith(isVeryClose: false)],
    );
  }

  void setSensitivity(WalkSensitivity sensitivity) {
    if (sensitivity == state.sensitivity) return;
    state = state.copyWith(sensitivity: sensitivity);
  }

  void toggleSound() {
    final enabled = !state.isSoundEnabled;
    if (!enabled) _buzzer.stopAlert();
    state = state.copyWith(isSoundEnabled: enabled);
  }

  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> turnOnBluetooth() async {
    try {
      await _repository.turnOnBluetooth();
    } catch (e, st) {
      _logger.warning('Could not turn Bluetooth on', e, st);
    }
  }

  /// One advertisement of a target (public for tests).
  @visibleForTesting
  void onSignal(String deviceId, int rssi, DateTime at) {
    if (!ref.mounted || !state.isRunning) return;
    final filter = _filters[deviceId];
    final alarm = _alarms[deviceId];
    if (filter == null || alarm == null) return;
    _monitor.clearError();

    filter.add(rssi, at);
    final smoothed = filter.smoothed!;
    final fire = alarm.update(
      smoothed,
      state.sensitivity.thresholdDbm.toDouble(),
      at,
    );
    state = state.copyWith(
      targets: [
        for (final t in state.targets)
          if (t.device.id == deviceId)
            t.copyWith(
              smoothedRssi: () => smoothed,
              lastHeard: () => at,
              isVeryClose: alarm.isInside,
            )
          else
            t,
      ],
    );
    if (fire) _alert();
  }

  /// Once a second: refresh "last heard" and treat silent targets as gone.
  @visibleForTesting
  void tick([DateTime? at]) {
    if (!ref.mounted || !state.isRunning) return;
    final now = at ?? DateTime.now();
    final targets = [
      for (final t in state.targets)
        if (t.isVeryClose && !t.isHeard(now)) _markLost(t) else t,
    ];
    state = state.copyWith(now: now, targets: targets);
  }

  WalkTarget _markLost(WalkTarget t) {
    _alarms[t.device.id]?.markLost(t.lastHeard ?? DateTime.now());
    return t.copyWith(isVeryClose: false);
  }

  void _alert() {
    if (state.isSoundEnabled) _buzzer.playAlert();
    _haptics.alertPattern();
    state = state.copyWith(alertCount: state.alertCount + 1);
  }

  void _onIssue(FinderScanIssue? issue) {
    if (!ref.mounted || !state.isRunning) return;
    state = state.copyWith(issue: () => issue);
  }

  void _stopScanning() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _monitor.stop();
    // Only the alert burst this screen plays; another screen's Geiger loop
    // is left alone.
    _buzzer.stopAlert();
    _repository.stopTracking(owner: RadarRepository.walkFinderOwner).catchError(
      (Object e, StackTrace st) {
        _logger.warning('Walk finder could not stop scanning', e, st);
      },
    );
  }

  void _dispose() {
    _stopScanning();
    _repository.releaseScreen(RadarRepository.walkFinderOwner);
  }
}

final walkFinderViewModelProvider =
    NotifierProvider.autoDispose<WalkFinderViewModel, WalkFinderState>(
      WalkFinderViewModel.new,
    );
