import 'dart:async';
import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/audio/haptic_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/radar/model/proximity_meter.dart';
import 'package:exam_guard/features/radar/model/radar_levels.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view_model/finder_aliases.dart';
import 'package:exam_guard/features/radar/view_model/rssi_trend_filter.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

class TrackingRadarState {
  final ScannedDeviceModel? device;

  /// Estimated distance from the smoothed RSSI; null until the first live
  /// packet arrives.
  final double? distanceMeters;

  /// Last raw RSSI received while tracking; null until the first packet.
  final int? rssi;

  /// Smoothed RSSI that distance, threat and trend are computed from.
  final double? smoothedRssi;
  final ThreatLevel threatLevel;
  final ProximityTrend trend;
  final List<int> rssiHistory;
  final bool isAudioAlertEnabled;

  /// Vibrate stronger / faster as closeness rises.
  final bool isVibrationEnabled;

  /// Highest closeness (0–100) since the target was chosen or the peak was
  /// reset ("best so far"), and the smoothed RSSI it was reached at.
  final int? peakCloseness;
  final double? peakRssi;

  /// True when the target has not advertised for [TrackingRadarViewModel.signalLostAfter].
  final bool isSignalLost;

  /// Translation key of the reason the Bluetooth scan could not start or
  /// failed; null while scanning normally.
  final String? errorKey;

  /// Location (GPS) is off, so Android delivers no Bluetooth results.
  /// Tracking resumes by itself once Location is back on.
  final bool isLocationOff;

  const TrackingRadarState({
    this.device,
    this.distanceMeters,
    this.rssi,
    this.smoothedRssi,
    this.threatLevel = ThreatLevel.low,
    this.trend = ProximityTrend.stationary,
    this.rssiHistory = const [],
    this.isAudioAlertEnabled = true,
    this.isVibrationEnabled = true,
    this.peakCloseness,
    this.peakRssi,
    this.isSignalLost = false,
    this.errorKey,
    this.isLocationOff = false,
  });

  /// Waiting for the first live packet from the target.
  bool get isAcquiring =>
      device != null &&
      smoothedRssi == null &&
      errorKey == null &&
      !isSignalLost;

  /// Distance, threat and trend reflect a current measurement.
  bool get hasLiveSignal =>
      smoothedRssi != null && !isSignalLost && errorKey == null;

  /// 0–100 % closeness from the smoothed RSSI; null without a live signal.
  int? get closeness {
    final rssi = smoothedRssi;
    if (rssi == null || !hasLiveSignal) return null;
    return ProximityMeter.closenessPercent(rssi);
  }

  TrackingRadarState copyWith({
    ScannedDeviceModel? device,
    double? Function()? distanceMeters,
    int? Function()? rssi,
    double? Function()? smoothedRssi,
    ThreatLevel? threatLevel,
    ProximityTrend? trend,
    List<int>? rssiHistory,
    bool? isAudioAlertEnabled,
    bool? isVibrationEnabled,
    int? Function()? peakCloseness,
    double? Function()? peakRssi,
    bool? isSignalLost,
    String? Function()? errorKey,
    bool? isLocationOff,
  }) {
    return TrackingRadarState(
      device: device ?? this.device,
      distanceMeters: distanceMeters != null
          ? distanceMeters()
          : this.distanceMeters,
      rssi: rssi != null ? rssi() : this.rssi,
      smoothedRssi: smoothedRssi != null ? smoothedRssi() : this.smoothedRssi,
      threatLevel: threatLevel ?? this.threatLevel,
      trend: trend ?? this.trend,
      rssiHistory: rssiHistory ?? this.rssiHistory,
      isAudioAlertEnabled: isAudioAlertEnabled ?? this.isAudioAlertEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      peakCloseness: peakCloseness != null
          ? peakCloseness()
          : this.peakCloseness,
      peakRssi: peakRssi != null ? peakRssi() : this.peakRssi,
      isSignalLost: isSignalLost ?? this.isSignalLost,
      errorKey: errorKey != null ? errorKey() : this.errorKey,
      isLocationOff: isLocationOff ?? this.isLocationOff,
    );
  }

  /// Typical RSSI of a phone-class transmitter at 1 m.
  static const int defaultRssiAt1m = -59;

  /// Expected RSSI at 1 m. The BLE TX Power Level is measured at 0 m, and
  /// free-space loss over the first metre at 2.4 GHz is about 41 dB.
  static int rssiAt1m(int? txPower) {
    if (txPower == null || txPower < -30 || txPower > 20) {
      return defaultRssiAt1m;
    }
    return txPower - 41;
  }

  /// Log-distance path loss estimate, in metres.
  static double calculateDistance(
    double rssi, {
    int rssiAt1m = defaultRssiAt1m,
    double n = 2.5,
  }) {
    final ratio = (rssiAt1m - rssi) / (10 * n);
    return math.pow(10, ratio).toDouble();
  }

  /// RSSI distance is rough (±50 % or worse), so show one decimal at most.
  static String formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters >= 10) return '>10 m';
    return '≈${meters.toStringAsFixed(1)} m';
  }
}

/// Live hot/cold tracking of one BLE device. Listens to every advertisement
/// from any of the target's addresses (phones use several and rotate them);
/// distance, threat and trend come from the smoothed RSSI.
class TrackingRadarViewModel extends Notifier<TrackingRadarState> {
  static const Duration signalLostAfter = Duration(seconds: 5);
  static const int _historyLength = 20;

  /// Packets of a fresh measurement before it may set the peak (the first
  /// packets are not smoothed yet).
  static const int peakWarmUpPackets = 3;

  late RadarRepository _repository;
  late GeigerBuzzerService _buzzer;
  late AppLogger _logger;
  late IHapticService _haptics;
  late FinderAliases _aliases;

  /// Addresses the target is heard on (see [FinderAliases]).
  Set<String> _targetIds = const {};
  final RssiTrendFilter _filter = RssiTrendFilter();
  final PeakHold _peak = PeakHold();
  final HapticPulseLimiter _pulses = HapticPulseLimiter();
  int _packetsSinceReset = 0;
  StreamSubscription<RadarSignal>? _sub;
  StreamSubscription<BleScanError?>? _problemSub;
  Timer? _lostTimer;
  DateTime _lastPacketAt = DateTime.now();

  /// True while another screen (e.g. the incident form) covers the radar.
  bool _alertsSuspended = false;

  @override
  TrackingRadarState build() {
    _repository = ref.watch(radarRepositoryProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    _logger = ref.watch(appLoggerProvider);
    _haptics = ref.watch(hapticServiceProvider);
    _aliases = FinderAliases(ref, _logger)..watch(_refreshAliases);
    // Keep the display on while the radar is open; released on dispose.
    _repository.keepScreenOn(RadarRepository.radarOwner);
    ref.onDispose(_stop);
    return const TrackingRadarState();
  }

  /// Starts tracking [device]. The scanner's last RSSI is stale, so nothing
  /// is shown until the first live packet arrives.
  Future<void> setTargetDevice(ScannedDeviceModel device) async {
    if (state.device?.id == device.id) return;
    _peak.reset();
    state = TrackingRadarState(
      device: device,
      isAudioAlertEnabled: state.isAudioAlertEnabled,
      isVibrationEnabled: state.isVibrationEnabled,
    );
    _lostTimer?.cancel();
    _lostTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkSignalLost();
    });
    await _startTracking();
  }

  /// Restarts the scan after an error.
  Future<void> retry() async {
    if (state.device == null) return;
    state = state.copyWith(
      errorKey: () => null,
      isSignalLost: false,
      isLocationOff: false,
    );
    await _startTracking();
  }

  /// Opens the system Location settings so the user can turn Location on.
  Future<void> openLocationSettings() => _repository.openLocationSettings();

  Future<void> _startTracking() async {
    final device = state.device;
    if (device == null) return;
    _resetFilter();
    _lastPacketAt = DateTime.now();

    _targetIds = _aliases.of(device.id);
    await _sub?.cancel();
    _sub = _repository
        .watchAll()
        .where((s) => _targetIds.contains(s.deviceId))
        .listen(
          (s) => updateDeviceSignal(s.rssi, s.timestamp),
          onError: (Object e, StackTrace st) {
            _logger.warning('Radar scan error', e, st);
            if (e is BleScanException && e.code == BleScanError.locationOff) {
              _onLocationOff();
              return;
            }
            _fail(
              e is BleScanException ? scanErrorKey(e) : 'radar_err_scan_failed',
            );
          },
        );
    _updateBuzzer();

    try {
      await _repository.startTracking();
    } on BleScanException catch (e) {
      _logger.warning('Radar scan failed to start', e);
      if (e.code != BleScanError.locationOff) {
        _fail(scanErrorKey(e));
        return;
      }
      // The scan stays registered and resumes once Location is back on.
      _onLocationOff();
    } catch (e, st) {
      _logger.error('Radar could not start scanning', e, st);
      _fail('radar_err_scan_start');
      return;
    }
    _watchScanProblem();
  }

  /// The scanner learned new addresses of the target (rotation, group).
  void _refreshAliases() {
    final device = state.device;
    if (!ref.mounted || device == null) return;
    _targetIds = _aliases.of(device.id);
  }

  /// Follows scan problems (Location off) while tracking. Re-subscribed on
  /// every start so the current problem is re-read.
  void _watchScanProblem() {
    _problemSub?.cancel();
    _problemSub = _repository.scanProblem().listen(
      (problem) {
        if (!ref.mounted || state.device == null) return;
        if (problem == BleScanError.locationOff) {
          _onLocationOff();
        } else if (state.isLocationOff) {
          _onLocationBack();
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.warning('Radar scan problem stream error', e, st);
      },
    );
  }

  /// Location went off: no packets can arrive, so stop showing a distance.
  void _onLocationOff() {
    if (!ref.mounted || state.isLocationOff) return;
    state = state.copyWith(
      isLocationOff: true,
      errorKey: () => locationOffErrorKey,
      trend: ProximityTrend.stationary,
    );
    _updateBuzzer();
  }

  /// Location is back on and the scan resumed by itself: wait for the first
  /// fresh packet instead of showing the pre-outage distance.
  void _onLocationBack() {
    if (!ref.mounted) return;
    _resetFilter();
    _lastPacketAt = DateTime.now();
    state = state.copyWith(
      isLocationOff: false,
      errorKey: () => null,
      isSignalLost: false,
      distanceMeters: () => null,
      rssi: () => null,
      smoothedRssi: () => null,
      trend: ProximityTrend.stationary,
    );
    _updateBuzzer();
  }

  /// Translation key for a scan failure reported by the Bluetooth service.
  static const String locationOffErrorKey = 'radar_err_location_off';

  static String scanErrorKey(BleScanException e) {
    if (e.code == BleScanError.locationOff) return locationOffErrorKey;
    if (e.code == BleScanError.throttled) return 'radar_err_scan_throttled';
    return 'radar_err_scan_failed';
  }

  void _fail(String errorKey) {
    if (!ref.mounted) return;
    state = state.copyWith(
      errorKey: () => errorKey,
      isLocationOff: false,
      trend: ProximityTrend.stationary,
    );
    _updateBuzzer();
  }

  void _checkSignalLost() {
    // While Location is off the location reason is shown instead.
    if (!ref.mounted || state.device == null || state.isLocationOff) return;
    final lost = DateTime.now().difference(_lastPacketAt) > signalLostAfter;
    if (lost == state.isSignalLost) return;
    state = state.copyWith(
      isSignalLost: lost,
      trend: lost ? ProximityTrend.stationary : null,
    );
    _updateBuzzer();
  }

  void updateDeviceSignal(int rssi, [DateTime? timeStamp]) {
    final device = state.device;
    if (!ref.mounted || device == null) return;
    final at = timeStamp ?? DateTime.now();
    _lastPacketAt = DateTime.now();

    _filter.add(rssi, at);
    _packetsSinceReset++;
    final smoothed = _filter.smoothed!;
    final closeness = ProximityMeter.closenessPercent(smoothed);
    if (_packetsSinceReset >= peakWarmUpPackets) {
      _peak.add(closeness, smoothed);
    }
    final distance = TrackingRadarState.calculateDistance(
      smoothed,
      rssiAt1m: TrackingRadarState.rssiAt1m(device.txPower),
    );

    final newHistory = [...state.rssiHistory, rssi];
    if (newHistory.length > _historyLength) newHistory.removeAt(0);

    state = state.copyWith(
      device: device.copyWith(rssi: rssi, lastSeen: at),
      distanceMeters: () => distance,
      rssi: () => rssi,
      smoothedRssi: () => smoothed,
      threatLevel: ThreatLevel.fromDistance(distance),
      trend: _filter.trend,
      rssiHistory: newHistory,
      peakCloseness: () => _peak.percent,
      peakRssi: () => _peak.rssi,
      isSignalLost: false,
      errorKey: () => null,
      isLocationOff: false,
    );
    _updateBuzzer();
    _pulseHaptics(closeness, DateTime.now());
  }

  void _resetFilter() {
    _filter.reset();
    _packetsSinceReset = 0;
    _pulses.reset();
  }

  /// Clears "best so far"; the next packets set a new peak.
  void resetPeak() {
    _peak.reset();
    _packetsSinceReset = 0;
    state = state.copyWith(peakCloseness: () => null, peakRssi: () => null);
  }

  void toggleVibration() {
    state = state.copyWith(isVibrationEnabled: !state.isVibrationEnabled);
  }

  /// Stronger, faster pulses as closeness rises (rate-limited per band).
  void _pulseHaptics(int closeness, DateTime now) {
    if (!state.isVibrationEnabled || _alertsSuspended || !state.hasLiveSignal) {
      return;
    }
    final strength = _pulses.next(closeness, now);
    if (strength != null) _haptics.pulse(strength);
  }

  void toggleAudioAlert() {
    state = state.copyWith(isAudioAlertEnabled: !state.isAudioAlertEnabled);
    _updateBuzzer();
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

  /// Evidence for the incident form.
  String incidentNotes() {
    final device = state.device;
    final name = device?.displayName ?? 'unknown device';
    if (state.isLocationOff) {
      return 'Radar: $name — not measuring when logged '
          '(Location (GPS) is off).';
    }
    if (!state.hasLiveSignal) {
      return 'Radar: $name — no live signal when logged.';
    }
    return 'Radar: $name estimated '
        '${TrackingRadarState.formatDistance(state.distanceMeters)} away '
        '(smoothed RSSI ${state.smoothedRssi!.round()} dBm, '
        '${state.threatLevel.label}).';
  }

  /// Beeps faster as the inspector gets closer; silent without a live signal.
  void _updateBuzzer() {
    final distance = state.distanceMeters;
    if (state.isAudioAlertEnabled &&
        !_alertsSuspended &&
        state.hasLiveSignal &&
        distance != null &&
        distance > 0) {
      _buzzer.updateTargetDistance(distance);
    } else {
      _buzzer.stopBuzzer();
    }
  }

  void _stop() {
    _lostTimer?.cancel();
    _sub?.cancel();
    _problemSub?.cancel();
    _buzzer.stopBuzzer();
    _repository.releaseScreen(RadarRepository.radarOwner);
    _repository.stopTracking().catchError((Object e, StackTrace st) {
      _logger.warning('Radar could not stop scanning', e, st);
    });
  }
}

final trackingRadarViewModelProvider =
    NotifierProvider.autoDispose<TrackingRadarViewModel, TrackingRadarState>(
      TrackingRadarViewModel.new,
    );
