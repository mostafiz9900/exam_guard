import 'dart:async';
import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

class TrackingRadarState {
  final ScannedDeviceModel? device;
  final double distanceMeters;
  final int rssi;
  final ThreatLevel threatLevel;
  final ProximityTrend trend;
  final List<int> rssiHistory;
  final bool isAudioAlertEnabled;

  /// True when the target has not advertised for [TrackingRadarViewModel.signalLostAfter].
  final bool isSignalLost;

  const TrackingRadarState({
    this.device,
    this.distanceMeters = 0.0,
    this.rssi = -100,
    this.threatLevel = ThreatLevel.low,
    this.trend = ProximityTrend.stationary,
    this.rssiHistory = const [],
    this.isAudioAlertEnabled = true,
    this.isSignalLost = false,
  });

  TrackingRadarState copyWith({
    ScannedDeviceModel? device,
    double? distanceMeters,
    int? rssi,
    ThreatLevel? threatLevel,
    ProximityTrend? trend,
    List<int>? rssiHistory,
    bool? isAudioAlertEnabled,
    bool? isSignalLost,
  }) {
    return TrackingRadarState(
      device: device ?? this.device,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rssi: rssi ?? this.rssi,
      threatLevel: threatLevel ?? this.threatLevel,
      trend: trend ?? this.trend,
      rssiHistory: rssiHistory ?? this.rssiHistory,
      isAudioAlertEnabled: isAudioAlertEnabled ?? this.isAudioAlertEnabled,
      isSignalLost: isSignalLost ?? this.isSignalLost,
    );
  }

  /// Calculates BLE distance using Log-Distance Path Loss model
  static double calculateDistance(
    int rssi, {
    int txPower = -59,
    double n = 2.5,
  }) {
    if (rssi == 0) return -1.0;
    final ratio = (txPower - rssi) / (10 * n);
    final distance = math.pow(10, ratio).toDouble();
    return double.parse(distance.toStringAsFixed(2));
  }

  /// Determines Threat Level based on RSSI
  static ThreatLevel calculateThreat(int rssi) {
    if (rssi > -60) {
      return ThreatLevel.critical;
    } else if (rssi > -75) {
      return ThreatLevel.high;
    } else if (rssi > -88) {
      return ThreatLevel.medium;
    } else {
      return ThreatLevel.low;
    }
  }

  /// Dynamic Proximity Trend calculation comparing current RSSI against moving average
  static ProximityTrend calculateTrend(int currentRssi, List<int> history) {
    if (history.length < 2) return ProximityTrend.stationary;
    final sub = history.length > 4
        ? history.sublist(history.length - 4, history.length - 1)
        : history.sublist(0, history.length - 1);
    final avgPrev = sub.reduce((a, b) => a + b) / sub.length;

    final diff = currentRssi - avgPrev;

    if (diff >= 1.2) {
      return ProximityTrend.approaching;
    } else if (diff <= -1.2) {
      return ProximityTrend.receding;
    } else {
      return ProximityTrend.stationary;
    }
  }
}

/// Live hot/cold tracking of one BLE device. Listens to every advertisement
/// from the target, so distance and trend update in real time.
class TrackingRadarViewModel extends Notifier<TrackingRadarState> {
  static const Duration signalLostAfter = Duration(seconds: 5);

  late RadarRepository _repository;
  late GeigerBuzzerService _buzzer;
  StreamSubscription<RadarSignal>? _sub;
  Timer? _lostTimer;

  @override
  TrackingRadarState build() {
    _repository = ref.watch(radarRepositoryProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    ref.onDispose(_stop);
    return const TrackingRadarState();
  }

  void setTargetDevice(ScannedDeviceModel device) {
    if (state.device?.id == device.id) return;

    state = state.copyWith(
      device: device,
      distanceMeters: TrackingRadarState.calculateDistance(device.rssi),
      rssi: device.rssi,
      threatLevel: TrackingRadarState.calculateThreat(device.rssi),
      trend: ProximityTrend.stationary,
      rssiHistory: [device.rssi],
      isSignalLost: false,
    );

    _sub?.cancel();
    _sub = _repository
        .watchDevice(device.id)
        .listen((s) => updateDeviceSignal(s.rssi, s.timestamp));
    _repository.startTracking();
    _updateBuzzer();

    _lostTimer?.cancel();
    _lostTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final target = state.device;
      if (!ref.mounted || target == null) return;
      final lost = DateTime.now().difference(target.lastSeen) > signalLostAfter;
      if (lost != state.isSignalLost) {
        state = state.copyWith(isSignalLost: lost);
        _updateBuzzer();
      }
    });
  }

  void updateDeviceSignal(int rssi, [DateTime? timeStamp]) {
    if (!ref.mounted || state.device == null) return;
    final updatedDevice = state.device!.copyWith(
      rssi: rssi,
      lastSeen: timeStamp ?? DateTime.now(),
    );

    final newHistory = [...state.rssiHistory, rssi];
    if (newHistory.length > 20) newHistory.removeAt(0);

    state = state.copyWith(
      device: updatedDevice,
      distanceMeters: TrackingRadarState.calculateDistance(rssi),
      rssi: rssi,
      threatLevel: TrackingRadarState.calculateThreat(rssi),
      trend: TrackingRadarState.calculateTrend(rssi, newHistory),
      rssiHistory: newHistory,
      isSignalLost: false,
    );
    _updateBuzzer();
  }

  void toggleAudioAlert() {
    state = state.copyWith(isAudioAlertEnabled: !state.isAudioAlertEnabled);
    _updateBuzzer();
  }

  /// Beeps faster as the inspector gets closer; silent when the signal is lost.
  void _updateBuzzer() {
    if (state.isAudioAlertEnabled &&
        !state.isSignalLost &&
        state.distanceMeters > 0) {
      _buzzer.updateTargetDistance(state.distanceMeters);
    } else {
      _buzzer.stopBuzzer();
    }
  }

  void _stop() {
    _lostTimer?.cancel();
    _sub?.cancel();
    _buzzer.stopBuzzer();
    _repository.stopTracking();
  }
}

final trackingRadarViewModelProvider =
    NotifierProvider.autoDispose<TrackingRadarViewModel, TrackingRadarState>(
      TrackingRadarViewModel.new,
    );
