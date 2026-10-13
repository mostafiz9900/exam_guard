import 'dart:async';
import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/bluetooth/i_bluetooth_service.dart';
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

  /// True when the target has not advertised for [TrackingRadarNotifier.signalLostAfter].
  final bool isSignalLost;

  const RadarTargetState({
    this.device,
    this.distanceMeters = 0.0,
    this.rssi = -100,
    this.threatLevel = ThreatLevel.low,
    this.trend = ProximityTrend.stationary,
    this.rssiHistory = const [],
    this.isAudioAlertEnabled = true,
    this.isSignalLost = false,
  });

  RadarTargetState copyWith({
    ScannedDeviceModel? device,
    double? distanceMeters,
    int? rssi,
    ThreatLevel? threatLevel,
    ProximityTrend? trend,
    List<int>? rssiHistory,
    bool? isAudioAlertEnabled,
    bool? isSignalLost,
  }) {
    return RadarTargetState(
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

/// Live hot/cold tracking of one BLE device. Listens to every advertisement
/// from the target, so distance and trend update in real time.
class TrackingRadarNotifier extends Notifier<RadarTargetState> {
  static const String _scanOwner = 'tracking_radar';
  static const Duration signalLostAfter = Duration(seconds: 5);

  late IBluetoothService _bluetooth;
  StreamSubscription<BleScanRecord>? _sub;
  Timer? _lostTimer;

  @override
  RadarTargetState build() {
    _bluetooth = ref.watch(bluetoothServiceProvider);
    ref.onDispose(_stop);
    return const RadarTargetState();
  }

  void setTargetDevice(ScannedDeviceModel device) {
    if (state.device?.id == device.id) return;

    state = state.copyWith(
      device: device,
      distanceMeters: RadarTargetState.calculateDistance(device.rssi),
      rssi: device.rssi,
      threatLevel: RadarTargetState.calculateThreat(device.rssi),
      trend: ProximityTrend.stationary,
      rssiHistory: [device.rssi],
      isSignalLost: false,
    );

    _sub?.cancel();
    _sub = _bluetooth.scanRecords
        .where((r) => r.id == device.id)
        .listen((r) => updateDeviceSignal(r.rssi, r.timestamp));
    _bluetooth.startScan(_scanOwner);

    _lostTimer?.cancel();
    _lostTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final target = state.device;
      if (!ref.mounted || target == null) return;
      final lost = DateTime.now().difference(target.lastSeen) > signalLostAfter;
      if (lost != state.isSignalLost) {
        state = state.copyWith(isSignalLost: lost);
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
      distanceMeters: RadarTargetState.calculateDistance(rssi),
      rssi: rssi,
      threatLevel: RadarTargetState.calculateThreat(rssi),
      trend: RadarTargetState.calculateTrend(rssi, newHistory),
      rssiHistory: newHistory,
      isSignalLost: false,
    );
  }

  void toggleAudioAlert() {
    state = state.copyWith(isAudioAlertEnabled: !state.isAudioAlertEnabled);
  }

  void _stop() {
    _lostTimer?.cancel();
    _sub?.cancel();
    _bluetooth.stopScan(_scanOwner);
  }
}

final trackingRadarProvider =
    NotifierProvider.autoDispose<TrackingRadarNotifier, RadarTargetState>(
  TrackingRadarNotifier.new,
);
