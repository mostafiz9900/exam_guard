import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../scanner/domain/scanned_device_model.dart';

enum ThreatLevel {
  critical,
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case ThreatLevel.critical:
        return 'CRITICAL PROXIMITY';
      case ThreatLevel.high:
        return 'HIGH PROXIMITY';
      case ThreatLevel.medium:
        return 'MODERATE PROXIMITY';
      case ThreatLevel.low:
        return 'LOW / DISTANT SIGNAL';
    }
  }

  String get description {
    switch (this) {
      case ThreatLevel.critical:
        return 'Target is within 1.5 meters. High risk of active transmission.';
      case ThreatLevel.high:
        return 'Target is within 1.5 - 3.5 meters of inspector.';
      case ThreatLevel.medium:
        return 'Target is within 3.5 - 6 meters range.';
      case ThreatLevel.low:
        return 'Target signal is weak or far away (>6 meters).';
    }
  }
}

enum ProximityTrend {
  approaching(
    'APPROACHING TARGET (GETTING CLOSER)',
    'Distance decreasing! Step forward towards candidate.',
    true,
  ),
  receding(
    'RECEDING (MOVING AWAY)',
    'Distance increasing! Turn 180° around or change aisle.',
    false,
  ),
  stationary(
    'STATIONARY LOCK (HOLD POSITION)',
    'Distance locked (±0.2m). Sweep phone left/right to pinpoint desk.',
    null,
  );

  const ProximityTrend(this.label, this.instruction, this.isCloser);
  final String label;
  final String instruction;
  final bool? isCloser;
}

class RadarTargetState {
  final ScannedDeviceModel? device;
  final double distanceMeters;
  final int rssi;
  final ThreatLevel threatLevel;
  final ProximityTrend trend;
  final List<int> rssiHistory;
  final bool isAudioAlertEnabled;

  const RadarTargetState({
    this.device,
    this.distanceMeters = 0.0,
    this.rssi = -100,
    this.threatLevel = ThreatLevel.low,
    this.trend = ProximityTrend.stationary,
    this.rssiHistory = const [],
    this.isAudioAlertEnabled = true,
  });

  RadarTargetState copyWith({
    ScannedDeviceModel? device,
    double? distanceMeters,
    int? rssi,
    ThreatLevel? threatLevel,
    ProximityTrend? trend,
    List<int>? rssiHistory,
    bool? isAudioAlertEnabled,
  }) {
    return RadarTargetState(
      device: device ?? this.device,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rssi: rssi ?? this.rssi,
      threatLevel: threatLevel ?? this.threatLevel,
      trend: trend ?? this.trend,
      rssiHistory: rssiHistory ?? this.rssiHistory,
      isAudioAlertEnabled: isAudioAlertEnabled ?? this.isAudioAlertEnabled,
    );
  }

  /// Calculates BLE distance using Log-Distance Path Loss model
  static double calculateDistance(int rssi, {int txPower = -59, double n = 2.5}) {
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

class TrackingRadarNotifier extends StateNotifier<RadarTargetState> {
  TrackingRadarNotifier() : super(const RadarTargetState());

  void setTargetDevice(ScannedDeviceModel device) {
    final dist = RadarTargetState.calculateDistance(device.rssi);
    final threat = RadarTargetState.calculateThreat(device.rssi);
    final history = [device.rssi];

    state = state.copyWith(
      device: device,
      distanceMeters: dist,
      rssi: device.rssi,
      threatLevel: threat,
      trend: ProximityTrend.stationary,
      rssiHistory: history,
    );
  }

  void updateDeviceSignal(int rssi, [DateTime? timeStamp]) {
    if (state.device == null) return;
    final updatedDevice = state.device!.copyWith(
      rssi: rssi,
      lastSeen: timeStamp ?? DateTime.now(),
    );
    final dist = RadarTargetState.calculateDistance(rssi);
    final threat = RadarTargetState.calculateThreat(rssi);

    final newHistory = List<int>.from(state.rssiHistory)..add(rssi);
    if (newHistory.length > 20) {
      newHistory.removeAt(0);
    }

    final trend = RadarTargetState.calculateTrend(rssi, newHistory);

    state = state.copyWith(
      device: updatedDevice,
      distanceMeters: dist,
      rssi: rssi,
      threatLevel: threat,
      trend: trend,
      rssiHistory: newHistory,
    );
  }

  void toggleAudioAlert() {
    state = state.copyWith(isAudioAlertEnabled: !state.isAudioAlertEnabled);
  }
}

final trackingRadarProvider =
    StateNotifierProvider<TrackingRadarNotifier, RadarTargetState>(
  (ref) => TrackingRadarNotifier(),
);
