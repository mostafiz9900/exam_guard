import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/sensors/i_magnetometer_service.dart';
import 'package:exam_guard/features/magnetic/model/magnetic_levels.dart';
import 'package:exam_guard/features/magnetic/repository/magnetic_repository.dart';

class MagneticState {
  final double magnitude; // Total Magnetic Field strength in Microteslas (μT)
  final double x;
  final double y;
  final double z;
  final double baseline;

  /// Total field of the sample with the biggest change since zeroing.
  final double peakValue;

  /// Biggest change from the baseline since zeroing (μT). A magnet can
  /// also lower the field, so this is not just [peakValue] − [baseline].
  final double peakChange;
  final bool isScanning;
  final bool isHardwareSensorActive;
  final bool isBuzzerEnabled;
  final MagneticSensitivity sensitivity;
  final List<double> history;
  final MagneticHazardLevel hazardLevel;

  /// Translation key of the reason the sensor is unavailable.
  final String? errorKey;

  /// False while the baseline is only the automatic first reading.
  final bool isBaselineCalibrated;

  /// Highest hazard level seen since the last calibration.
  final MagneticHazardLevel peakHazard;

  /// The OS compass calibration is missing or poor: ask for a figure-8.
  final bool needsCalibration;

  /// Raw sensor (phone bias included): only changes are meaningful.
  final bool isRawSensor;

  const MagneticState({
    this.magnitude = 0,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.baseline = 0,
    this.peakValue = 0,
    this.peakChange = 0,
    this.isScanning = false,
    this.isHardwareSensorActive = false,
    this.isBuzzerEnabled = true,
    this.sensitivity = MagneticSensitivity.medium,
    this.history = const [],
    this.hazardLevel = MagneticHazardLevel.normal,
    this.errorKey,
    this.isBaselineCalibrated = false,
    this.peakHazard = MagneticHazardLevel.normal,
    this.needsCalibration = false,
    this.isRawSensor = false,
  });

  /// Change from the baseline, the number that matters (μT).
  double get change => (magnitude - baseline).abs();

  bool get hasReading => isHardwareSensorActive;

  /// The phone has no (working) magnetometer: magnetic scanning is not
  /// possible on this device. Distinct from "waiting" (sensor starting) and
  /// "paused" (stopped by the user).
  bool get isSensorUnavailable =>
      errorKey == MagneticViewModel.noSensorErrorKey;

  /// Sensor started but no reading yet.
  bool get isWaitingForSensor =>
      isScanning && !isHardwareSensorActive && errorKey == null;

  /// Stopped by the user.
  bool get isPaused => !isScanning && errorKey == null;

  /// Readings are real only while the sensor is running and delivering.
  bool get isLive => isScanning && isHardwareSensorActive && errorKey == null;

  MagneticState copyWith({
    double? magnitude,
    double? x,
    double? y,
    double? z,
    double? baseline,
    double? peakValue,
    double? peakChange,
    bool? isScanning,
    bool? isHardwareSensorActive,
    bool? isBuzzerEnabled,
    MagneticSensitivity? sensitivity,
    List<double>? history,
    MagneticHazardLevel? hazardLevel,
    String? Function()? errorKey,
    bool? isBaselineCalibrated,
    MagneticHazardLevel? peakHazard,
    bool? needsCalibration,
    bool? isRawSensor,
  }) {
    return MagneticState(
      magnitude: magnitude ?? this.magnitude,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      baseline: baseline ?? this.baseline,
      peakValue: peakValue ?? this.peakValue,
      peakChange: peakChange ?? this.peakChange,
      isScanning: isScanning ?? this.isScanning,
      isHardwareSensorActive:
          isHardwareSensorActive ?? this.isHardwareSensorActive,
      isBuzzerEnabled: isBuzzerEnabled ?? this.isBuzzerEnabled,
      sensitivity: sensitivity ?? this.sensitivity,
      history: history ?? this.history,
      hazardLevel: hazardLevel ?? this.hazardLevel,
      errorKey: errorKey != null ? errorKey() : this.errorKey,
      isBaselineCalibrated: isBaselineCalibrated ?? this.isBaselineCalibrated,
      peakHazard: peakHazard ?? this.peakHazard,
      needsCalibration: needsCalibration ?? this.needsCalibration,
      isRawSensor: isRawSensor ?? this.isRawSensor,
    );
  }

  /// Total field above this (μT) is a strong source whatever the baseline;
  /// Earth's field is only 25–65 μT.
  static const double strongSourceMagnitude = 200.0;

  /// All levels come from the change from [baseline]:
  /// elevated > T, critical > 2T, strong source > 4T (T = preset threshold).
  /// The absolute [strongSourceMagnitude] rule needs a [calibrated]
  /// reading: a raw sensor includes the phone's own bias.
  static MagneticHazardLevel calculateHazard(
    double magnitude,
    double baseline,
    MagneticSensitivity sensitivity, {
    bool calibrated = true,
  }) {
    final delta = (magnitude - baseline).abs();
    final t = sensitivity.threshold;

    if (delta > 4 * t || (calibrated && magnitude > strongSourceMagnitude)) {
      return MagneticHazardLevel.strongSource;
    } else if (delta > 2 * t) {
      return MagneticHazardLevel.critical;
    } else if (delta > t) {
      return MagneticHazardLevel.elevated;
    } else {
      return MagneticHazardLevel.normal;
    }
  }
}

/// Live magnetometer reader. Uses only the phone's real sensor.
class MagneticViewModel extends Notifier<MagneticState> {
  static const String noSensorErrorKey = 'mag_err_no_sensor';
  static const Duration _noSensorTimeout = Duration(seconds: 2);
  static const int _historyLength = 16;

  /// The automatic baseline is the median of the first readings, so a
  /// warm-up glitch can't become the reference.
  @visibleForTesting
  static int settleSamples = 5;

  /// While nothing is detected the baseline follows slow drift (tilting,
  /// walking, temperature) by this share per sample (~2 s at 50 Hz), up to
  /// [_driftBand] of the threshold. A magnet's field rises as 1/r³, so it
  /// arrives as a jump within a fraction of a second, far past the band:
  /// the baseline never chases a real source.
  static const double _driftPerSample = 0.01;
  static const double _driftBand = 0.6;

  /// The sensor streams at ~50 Hz; publish to the UI at ~10 Hz. Every
  /// sample still updates peak/hazard, and each publish shows the strongest
  /// sample since the last one so quick passes are not missed.
  static const Duration _uiInterval = Duration(milliseconds: 100);

  late MagneticRepository _repository;
  late AppLogger _logger;
  late GeigerBuzzerService _buzzer;

  /// Beeps only while the magnetic screen is open, so the dashboard's
  /// background monitoring stays silent.
  bool _isScreenVisible = false;

  /// True while another screen (e.g. the incident form) covers this one.
  bool _alertsSuspended = false;

  StreamSubscription<MagneticSample>? _subscription;
  Timer? _noSensorTimer;
  Timer? _publishTimer;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  bool _hasBaseline = false;
  final List<double> _settle = [];

  /// Latest raw sample (rounded magnitude), whether published or not.
  double? _latestMagnitude;

  double _peak = 0;
  double _peakChange = 0;
  MagnetometerAccuracy _accuracy = MagnetometerAccuracy.unknown;
  MagneticHazardLevel _peakHazard = MagneticHazardLevel.normal;

  /// Strongest sample (largest change from baseline) since the last publish.
  MagneticSample? _pending;
  double _pendingMagnitude = 0;
  double _pendingDelta = -1;
  MagneticHazardLevel _pendingHazard = MagneticHazardLevel.normal;

  @override
  MagneticState build() {
    _repository = ref.watch(magneticRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    ref.onDispose(() {
      _cancel();
      if (_isScreenVisible) _buzzer.stopBuzzer();
    });
    Future.microtask(startScanning);
    return const MagneticState();
  }

  void setSensitivity(MagneticSensitivity s) {
    final hazard = MagneticState.calculateHazard(
      state.magnitude,
      state.baseline,
      s,
      calibrated: !state.isRawSensor,
    );
    _peakHazard = hazard;
    state = state.copyWith(
      sensitivity: s,
      hazardLevel: hazard,
      peakHazard: hazard,
    );
    _updateBuzzer();
  }

  void toggleBuzzer() {
    state = state.copyWith(isBuzzerEnabled: !state.isBuzzerEnabled);
    _updateBuzzer();
  }

  /// Called by the magnetic screen when it opens and closes.
  void setScreenVisible(bool visible) {
    _isScreenVisible = visible;
    if (!ref.mounted) {
      if (!visible) _buzzer.stopBuzzer();
      return;
    }
    if (visible) {
      _updateBuzzer();
    } else {
      _buzzer.stopBuzzer();
    }
  }

  /// Silences the buzzer while another screen is on top (e.g. the incident
  /// form) and resumes it afterwards.
  void setAlertsSuspended(bool suspended) {
    _alertsSuspended = suspended;
    if (ref.mounted) {
      _updateBuzzer();
    } else if (suspended) {
      _buzzer.stopBuzzer();
    }
  }

  /// Beeps faster as the field anomaly gets stronger.
  void _updateBuzzer() {
    if (!_isScreenVisible) return;
    final distance = !state.isBuzzerEnabled || _alertsSuspended || !state.isLive
        ? null
        : switch (state.hazardLevel) {
            MagneticHazardLevel.normal => null,
            MagneticHazardLevel.elevated => 4.0,
            MagneticHazardLevel.critical => 2.0,
            MagneticHazardLevel.strongSource => 0.5,
          };
    if (distance == null) {
      _buzzer.stopBuzzer();
    } else {
      _buzzer.updateTargetDistance(distance);
    }
  }

  void startScanning() {
    _cancel();
    if (!ref.mounted) return;
    _resetPending();
    _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
    // The phone may have moved while paused: an automatic baseline is
    // measured again; a "Set zero" baseline is the invigilator's choice.
    if (!state.isBaselineCalibrated) _resettle();
    state = state.copyWith(
      isScanning: true,
      isHardwareSensorActive: false,
      errorKey: () => null,
    );

    _subscription = _repository.samples().listen(
      _onReading,
      onError: (Object e, StackTrace st) {
        _logger.warning('Magnetometer stream error', e, st);
        _markUnavailable();
      },
    );

    // No reading at all: this phone almost certainly has no magnetometer.
    // Keep listening, so a merely slow sensor still comes live by itself.
    _noSensorTimer = Timer(_noSensorTimeout, () {
      if (!state.isHardwareSensorActive) _markUnavailable(keepListening: true);
    });
  }

  void _onReading(MagneticSample event) {
    if (!ref.mounted) return;
    _noSensorTimer?.cancel();

    // iOS before its first compass calibration: no usable field yet.
    if (!event.isCalibrated &&
        event.accuracy == MagnetometerAccuracy.uncalibrated) {
      if (!state.needsCalibration) {
        state = state.copyWith(needsCalibration: true);
      }
      return;
    }

    // When the OS calibration improves its bias estimate changes, so the
    // field jumps although nothing moved: measure the baseline again.
    final accuracy = event.accuracy;
    if (accuracy.index > _accuracy.index &&
        _accuracy != MagnetometerAccuracy.unknown) {
      _resettle();
    }
    _accuracy = accuracy;

    // Without OS calibration the field may still carry the phone's bias.
    final calibrated =
        event.isCalibrated && accuracy != MagnetometerAccuracy.uncalibrated;
    final needsCalibration = accuracy.needsCalibration;
    if (needsCalibration != state.needsCalibration ||
        !calibrated != state.isRawSensor) {
      state = state.copyWith(
        needsCalibration: needsCalibration,
        isRawSensor: !calibrated,
      );
    }
    final rounded = _round(event.magnitude);
    _latestMagnitude = rounded;

    if (!_hasBaseline) {
      _settle.add(rounded);
      if (_settle.length < settleSamples) return;
      _hasBaseline = true;
      state = state.copyWith(baseline: _median(_settle));
      _settle.clear();
    }
    var baseline = state.baseline;

    final hazard = MagneticState.calculateHazard(
      rounded,
      baseline,
      state.sensitivity,
      calibrated: calibrated,
    );
    if (hazard == MagneticHazardLevel.normal &&
        (rounded - baseline).abs() < state.sensitivity.threshold * _driftBand) {
      baseline += (rounded - baseline) * _driftPerSample;
      state = state.copyWith(baseline: baseline);
    }
    final delta = (rounded - baseline).abs();
    if (delta > _peakChange) {
      _peakChange = delta;
      _peak = rounded;
    }
    if (hazard.index > _peakHazard.index) _peakHazard = hazard;

    if (_pending == null ||
        hazard.index > _pendingHazard.index ||
        (hazard == _pendingHazard && delta > _pendingDelta)) {
      _pending = event;
      _pendingMagnitude = rounded;
      _pendingDelta = delta;
      _pendingHazard = hazard;
    }

    final sinceLast = DateTime.now().difference(_lastPublish);
    if (state.isHardwareSensorActive && sinceLast < _uiInterval) {
      // Publish what is pending once the interval is up, even if the
      // stream goes quiet, so a final spike is never lost.
      _publishTimer ??= Timer(_uiInterval - sinceLast, () {
        _publishTimer = null;
        _publishPending();
      });
      return;
    }
    _publishPending();
  }

  /// The baseline is already in [state] (drift may have moved it since
  /// this publish was scheduled), so it is not passed along.
  void _publishPending() {
    final shown = _pending;
    if (!ref.mounted || shown == null) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    _lastPublish = DateTime.now();

    final history = [...state.history, _pendingMagnitude];
    if (history.length > _historyLength) history.removeAt(0);

    state = state.copyWith(
      magnitude: _pendingMagnitude,
      x: _round(shown.x),
      y: _round(shown.y),
      z: _round(shown.z),
      peakValue: _peak,
      peakChange: _peakChange,
      history: history,
      hazardLevel: _pendingHazard,
      peakHazard: _peakHazard,
      isScanning: true,
      isHardwareSensorActive: true,
      errorKey: () => null,
    );
    _resetPending();
    _updateBuzzer();
  }

  void _resetPending() {
    _pending = null;
    _pendingMagnitude = 0;
    _pendingDelta = -1;
    _pendingHazard = MagneticHazardLevel.normal;
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(1));

  void _markUnavailable({bool keepListening = false}) {
    if (!ref.mounted) return;
    if (keepListening) {
      _noSensorTimer?.cancel();
      _noSensorTimer = null;
    } else {
      _cancel();
    }
    state = state.copyWith(
      isScanning: false,
      isHardwareSensorActive: false,
      hazardLevel: MagneticHazardLevel.normal,
      errorKey: () => noSensorErrorKey,
    );
    _updateBuzzer();
  }

  void stopScanning() {
    _cancel();
    state = state.copyWith(
      isScanning: false,
      hazardLevel: MagneticHazardLevel.normal,
    );
    _updateBuzzer();
  }

  /// Sets the current live field as the ambient baseline. Returns false
  /// (and changes nothing) when the sensor is not delivering live readings.
  bool calibrateBaseline() {
    final current = _latestMagnitude;
    if (!state.isLive || current == null) return false;
    _hasBaseline = true;
    _settle.clear();
    _peak = current;
    _peakChange = 0;
    _peakHazard = MagneticHazardLevel.normal;
    _resetPending();
    state = state.copyWith(
      magnitude: current,
      baseline: current,
      peakValue: current,
      peakChange: 0,
      isBaselineCalibrated: true,
      peakHazard: MagneticHazardLevel.normal,
      hazardLevel: MagneticHazardLevel.normal,
    );
    _updateBuzzer();
    return true;
  }

  /// Evidence for the incident form.
  String incidentNotes() {
    final baselineKind = state.isBaselineCalibrated ? 'calibrated' : 'auto';
    final live = state.isLive ? '' : ' Sensor was not live when logged.';
    return 'Magnetometer: peak ${state.peakValue.toStringAsFixed(1)} μT, '
        'change ${state.peakChange.toStringAsFixed(1)} μT '
        '(baseline ${state.baseline.toStringAsFixed(1)} μT $baselineKind, '
        'highest level ${state.peakHazard.label}, '
        '${state.sensitivity.chipLabel}).$live';
  }

  /// Measures the automatic baseline again from the next readings and
  /// forgets the peaks measured against the old one.
  void _resettle() {
    _hasBaseline = false;
    _settle.clear();
    _peak = 0;
    _peakChange = 0;
    _peakHazard = MagneticHazardLevel.normal;
    _resetPending();
    state = state.copyWith(
      isBaselineCalibrated: false,
      peakValue: 0,
      peakChange: 0,
      peakHazard: MagneticHazardLevel.normal,
      hazardLevel: MagneticHazardLevel.normal,
    );
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    _noSensorTimer?.cancel();
    _noSensorTimer = null;
    _publishTimer?.cancel();
    _publishTimer = null;
  }
}

/// Auto-disposed so the sensor stops once the dashboard and magnetic
/// screens are gone (e.g. after End Exam).
final magneticViewModelProvider =
    NotifierProvider.autoDispose<MagneticViewModel, MagneticState>(
      MagneticViewModel.new,
    );
