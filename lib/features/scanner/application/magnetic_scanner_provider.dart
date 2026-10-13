import 'dart:async';
import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/logger/app_logger.dart';
import '../../../core/services/sensors/i_magnetometer_service.dart';

enum MagneticHazardLevel {
  normal,
  elevated,
  critical,
  strongSource;

  String get label {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'NORMAL AMBIENT FIELD';
      case MagneticHazardLevel.elevated:
        return 'METAL / ANOMALY DETECTED';
      case MagneticHazardLevel.critical:
        return 'STRONG MAGNETIC ANOMALY';
      case MagneticHazardLevel.strongSource:
        return 'VERY STRONG SOURCE — DEVICE AT CONTACT RANGE';
    }
  }

  String get suggestion {
    switch (this) {
      case MagneticHazardLevel.normal:
        return 'No metallic or magnetic anomalies nearby.';
      case MagneticHazardLevel.elevated:
        return 'Suspected hidden metal / earpiece magnet. Check clothing pockets or seat.';
      case MagneticHazardLevel.critical:
        return 'Strong field change. A phone, smartwatch or speaker magnet is likely very close.';
      case MagneticHazardLevel.strongSource:
        return 'Field is far above normal. An electronic device or magnet is touching the phone area — inspect now.';
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
    this.magnitude = 0,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.baseline = 0,
    this.peakValue = 0,
    this.isScanning = false,
    this.isHardwareSensorActive = false,
    this.isBuzzerEnabled = true,
    this.sensitivity = MagneticSensitivity.balanced,
    this.history = const [],
    this.hazardLevel = MagneticHazardLevel.normal,
    this.errorMessage,
  });

  bool get hasReading => isHardwareSensorActive;

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
    String? Function()? errorMessage,
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
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
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
      return MagneticHazardLevel.strongSource;
    } else if (delta > (limit - baseline + 30) || magnitude > 90.0) {
      return MagneticHazardLevel.critical;
    } else if (delta > (limit - baseline) || magnitude > limit) {
      return MagneticHazardLevel.elevated;
    } else {
      return MagneticHazardLevel.normal;
    }
  }
}

/// Live magnetometer reader. Uses only the phone's real sensor.
class MagneticScannerNotifier extends Notifier<MagneticScannerState> {
  static const Duration _noSensorTimeout = Duration(seconds: 2);
  static const int _historyLength = 16;

  /// The sensor streams at ~50 Hz; publish to the UI at ~10 Hz.
  static const Duration _uiInterval = Duration(milliseconds: 100);

  late IMagnetometerService _sensor;
  late AppLogger _logger;

  StreamSubscription<MagnetometerReading>? _subscription;
  Timer? _noSensorTimer;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  bool _hasBaseline = false;

  @override
  MagneticScannerState build() {
    _sensor = ref.watch(magnetometerServiceProvider);
    _logger = ref.watch(appLoggerProvider);
    ref.onDispose(_cancel);
    Future.microtask(startScanning);
    return const MagneticScannerState();
  }

  void setSensitivity(MagneticSensitivity s) {
    final hazard = MagneticScannerState.calculateHazard(
        state.magnitude, state.baseline, s);
    state = state.copyWith(sensitivity: s, hazardLevel: hazard);
  }

  void toggleBuzzer() {
    state = state.copyWith(isBuzzerEnabled: !state.isBuzzerEnabled);
  }

  void startScanning() {
    _cancel();
    if (!ref.mounted) return;
    state = state.copyWith(isScanning: true, errorMessage: () => null);

    _subscription = _sensor.readings().listen(
      _onReading,
      onError: (Object e, StackTrace st) {
        _logger.warning('Magnetometer stream error', e, st);
        _markUnavailable();
      },
    );

    _noSensorTimer = Timer(_noSensorTimeout, () {
      if (!state.isHardwareSensorActive) _markUnavailable();
    });
  }

  void _onReading(MagnetometerReading event) {
    if (!ref.mounted) return;
    _noSensorTimer?.cancel();

    final now = DateTime.now();
    if (state.isHardwareSensorActive &&
        now.difference(_lastPublish) < _uiInterval) {
      return;
    }
    _lastPublish = now;

    final mag = math.sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );
    final rounded = double.parse(mag.toStringAsFixed(1));

    // The first real reading becomes the ambient baseline.
    final baseline = _hasBaseline ? state.baseline : rounded;
    _hasBaseline = true;

    final peak = math.max(state.peakValue, rounded);
    final hazard = MagneticScannerState.calculateHazard(
      rounded,
      baseline,
      state.sensitivity,
    );

    final history = [...state.history, rounded];
    if (history.length > _historyLength) history.removeAt(0);

    state = state.copyWith(
      magnitude: rounded,
      x: double.parse(event.x.toStringAsFixed(1)),
      y: double.parse(event.y.toStringAsFixed(1)),
      z: double.parse(event.z.toStringAsFixed(1)),
      baseline: baseline,
      peakValue: peak,
      history: history,
      hazardLevel: hazard,
      isScanning: true,
      isHardwareSensorActive: true,
    );
  }

  void _markUnavailable() {
    if (!ref.mounted) return;
    _cancel();
    state = state.copyWith(
      isScanning: false,
      isHardwareSensorActive: false,
      errorMessage: () => 'This phone has no working magnetometer sensor.',
    );
  }

  void stopScanning() {
    _cancel();
    state = state.copyWith(isScanning: false);
  }

  void calibrateBaseline() {
    state =
        state.copyWith(baseline: state.magnitude, peakValue: state.magnitude);
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    _noSensorTimer?.cancel();
    _noSensorTimer = null;
  }
}

final magneticScannerProvider =
    NotifierProvider<MagneticScannerNotifier, MagneticScannerState>(
  MagneticScannerNotifier.new,
);
