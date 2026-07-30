import 'dart:async';
import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum MagneticHazardLevel {
  normal,
  elevated,
  critical,
  cellCallDetected;

  String get label {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'NORMAL AMBIENT FIELD';
      case MagneticHazardLevel.elevated:
        return 'METAL / ANOMALY DETECTED';
      case MagneticHazardLevel.critical:
        return 'HIGH EMP / ELECTRONIC HAZARD';
      case MagneticHazardLevel.cellCallDetected:
        return 'ACTIVE CALL / DATA TRANSMISSION!';
    }
  }

  String get suggestion {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'No metallic or active electronic anomalies nearby.';
      case MagneticHazardLevel.elevated:
        return 'Suspected hidden metal / earpiece magnet. Check clothing pockets or seat.';
      case MagneticHazardLevel.critical:
        return 'Critical electromagnetic field! Active smartphone, smartwatch or EMP device in immediate proximity.';
      case MagneticHazardLevel.cellCallDetected:
        return 'Active phone call or 4G/5G data stream detected! Inspect candidate desk immediately.';
    }
  }
}

enum MagneticSensitivity {
  high(55.0, 'HIGH (0.5m Detect)'),
  balanced(72.0, 'BALANCED (1.0m Detect)'),
  extreme(100.0, 'HIGH METAL (1.5m Detect)');

  const MagneticSensitivity(this.threshold, this.label);
  final double threshold;
  final String label;
}

class MagneticScannerState {
  final double magnitude; // Total Magnetic Field strength in Microteslas (μT)
  final double x;
  final double y;
  final double z;
  final double baseline;
  final double peakValue;
  final bool isScanning;
  final bool isHardwareSensorActive;
  final bool isBuzzerEnabled;
  final MagneticSensitivity sensitivity;
  final List<double> history;
  final MagneticHazardLevel hazardLevel;
  final String? errorMessage;

  const MagneticScannerState({
    this.magnitude = 48.5,
    this.x = 22.1,
    this.y = -18.4,
    this.z = 39.2,
    this.baseline = 48.0,
    this.peakValue = 48.5,
    this.isScanning = false,
    this.isHardwareSensorActive = false,
    this.isBuzzerEnabled = true,
    this.sensitivity = MagneticSensitivity.balanced,
    this.history = const [48.0, 48.2, 48.5, 48.1, 48.6, 48.3, 48.5],
    this.hazardLevel = MagneticHazardLevel.normal,
    this.errorMessage,
  });

  MagneticScannerState copyWith({
    double? magnitude,
    double? x,
    double? y,
    double? z,
    double? baseline,
    double? peakValue,
    bool? isScanning,
    bool? isHardwareSensorActive,
    bool? isBuzzerEnabled,
    MagneticSensitivity? sensitivity,
    List<double>? history,
    MagneticHazardLevel? hazardLevel,
    String? errorMessage,
  }) {
    return MagneticScannerState(
      magnitude: magnitude ?? this.magnitude,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      baseline: baseline ?? this.baseline,
      peakValue: peakValue ?? this.peakValue,
      isScanning: isScanning ?? this.isScanning,
      isHardwareSensorActive:
          isHardwareSensorActive ?? this.isHardwareSensorActive,
      isBuzzerEnabled: isBuzzerEnabled ?? this.isBuzzerEnabled,
      sensitivity: sensitivity ?? this.sensitivity,
      history: history ?? this.history,
      hazardLevel: hazardLevel ?? this.hazardLevel,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static MagneticHazardLevel calculateHazard(
    double magnitude,
    double baseline,
    MagneticSensitivity sensitivity,
  ) {
    final delta = (magnitude - baseline).abs();
    final limit = sensitivity.threshold;

    if (magnitude > 120.0 || delta > 60.0) {
      return MagneticHazardLevel.cellCallDetected;
    } else if (delta > (limit - baseline + 30) || magnitude > 90.0) {
      return MagneticHazardLevel.critical;
    } else if (delta > (limit - baseline) || magnitude > limit) {
      return MagneticHazardLevel.elevated;
    } else {
      return MagneticHazardLevel.normal;
    }
  }
}

class MagneticScannerNotifier extends StateNotifier<MagneticScannerState> {
  MagneticScannerNotifier() : super(const MagneticScannerState()) {
    startScanning();
  }

  StreamSubscription<MagnetometerEvent>? _subscription;
  Timer? _fallbackTimer;
  Timer? _simulationTicker;
  final math.Random _random = math.Random();

  void setSensitivity(MagneticSensitivity s) {
    final hazard = MagneticScannerState.calculateHazard(
        state.magnitude, state.baseline, s);
    state = state.copyWith(sensitivity: s, hazardLevel: hazard);
  }

  void toggleBuzzer() {
    state = state.copyWith(isBuzzerEnabled: !state.isBuzzerEnabled);
  }

  void startScanning() {
    stopScanning();
    state = state.copyWith(isScanning: true, errorMessage: null);

    bool receivedHardwareEvent = false;

    try {
      _subscription = magnetometerEventStream().listen(
        (event) {
          receivedHardwareEvent = true;
          _fallbackTimer?.cancel();

          final mag = math.sqrt(
            (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
          );
          final peak = math.max(state.peakValue, mag);
          final hazard = MagneticScannerState.calculateHazard(
            mag,
            state.baseline,
            state.sensitivity,
          );

          final newHist = List<double>.from(state.history)..add(mag);
          if (newHist.length > 16) newHist.removeAt(0);

          state = state.copyWith(
            magnitude: double.parse(mag.toStringAsFixed(1)),
            x: double.parse(event.x.toStringAsFixed(1)),
            y: double.parse(event.y.toStringAsFixed(1)),
            z: double.parse(event.z.toStringAsFixed(1)),
            peakValue: double.parse(peak.toStringAsFixed(1)),
            history: newHist,
            hazardLevel: hazard,
            isScanning: true,
            isHardwareSensorActive: true,
          );
        },
        onError: (Object error) {
          _startSimulationFallback();
        },
      );
    } catch (_) {
      _startSimulationFallback();
    }

    _fallbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!receivedHardwareEvent) {
        _startSimulationFallback();
      }
    });
  }

  void _startSimulationFallback() {
    if (_simulationTicker != null && _simulationTicker!.isActive) return;

    state = state.copyWith(
      isHardwareSensorActive: false,
      isScanning: true,
    );

    _simulationTicker =
        Timer.periodic(const Duration(milliseconds: 300), (_) {
      final noiseX = 20.0 + (_random.nextDouble() * 6.0 - 3.0);
      final noiseY = -18.0 + (_random.nextDouble() * 6.0 - 3.0);
      final noiseZ = 38.0 + (_random.nextDouble() * 6.0 - 3.0);

      final mag =
          math.sqrt((noiseX * noiseX) + (noiseY * noiseY) + (noiseZ * noiseZ));
      final peak = math.max(state.peakValue, mag);
      final hazard = MagneticScannerState.calculateHazard(
        mag,
        state.baseline,
        state.sensitivity,
      );

      final newHist = List<double>.from(state.history)..add(mag);
      if (newHist.length > 16) newHist.removeAt(0);

      state = state.copyWith(
        magnitude: double.parse(mag.toStringAsFixed(1)),
        x: double.parse(noiseX.toStringAsFixed(1)),
        y: double.parse(noiseY.toStringAsFixed(1)),
        z: double.parse(noiseZ.toStringAsFixed(1)),
        peakValue: double.parse(peak.toStringAsFixed(1)),
        history: newHist,
        hazardLevel: hazard,
      );
    });
  }

  /// Trigger simulated metal / electronic device anomaly for testing
  void triggerSimulatedMetalAnomaly() {
    final metalMag = 128.5 + _random.nextDouble() * 35.0;
    final peak = math.max(state.peakValue, metalMag);
    final hazard = MagneticScannerState.calculateHazard(
      metalMag,
      state.baseline,
      state.sensitivity,
    );

    final newHist = List<double>.from(state.history)..add(metalMag);
    if (newHist.length > 16) newHist.removeAt(0);

    state = state.copyWith(
      magnitude: double.parse(metalMag.toStringAsFixed(1)),
      x: 75.2,
      y: 62.1,
      z: 88.4,
      peakValue: double.parse(peak.toStringAsFixed(1)),
      history: newHist,
      hazardLevel: hazard,
    );
  }

  void stopScanning() {
    _subscription?.cancel();
    _subscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _simulationTicker?.cancel();
    _simulationTicker = null;
    state = state.copyWith(isScanning: false);
  }

  void calibrateBaseline() {
    state =
        state.copyWith(baseline: state.magnitude, peakValue: state.magnitude);
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}

final magneticScannerProvider =
    StateNotifierProvider<MagneticScannerNotifier, MagneticScannerState>(
  (ref) => MagneticScannerNotifier(),
);
