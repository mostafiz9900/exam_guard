import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/rf_detector/model/rf_threat_level.dart';
import 'package:exam_guard/features/rf_detector/repository/rf_repository.dart';

class RfDetectorState {
  /// Strongest 2.4 GHz signal received in the last window; null when silent.
  final double? currentDbm;
  final double? peakDbm;
  final int packetsPerSecond;
  final int activeTransmitters;
  final String? strongestSourceName;
  final bool isScanning;
  final String? hardwareNodeName;
  final bool isBuzzerEnabled;
  final List<double> history;
  final RfThreatLevel threatLevel;

  /// Translation key of the reason the meter is not measuring.
  final String? errorKey;

  /// Permission request / scan start in progress.
  final bool isStarting;

  /// The Bluetooth adapter is off; the user must turn it on.
  final bool isBluetoothOff;

  const RfDetectorState({
    this.currentDbm,
    this.peakDbm,
    this.packetsPerSecond = 0,
    this.activeTransmitters = 0,
    this.strongestSourceName,
    this.isScanning = false,
    this.hardwareNodeName,
    this.isBuzzerEnabled = true,
    this.history = const [],
    this.threatLevel = RfThreatLevel.quiet,
    this.errorKey,
    this.isStarting = false,
    this.isBluetoothOff = false,
  });

  bool get isHardwareNodeNearby => hardwareNodeName != null;

  /// Readings are real only while the radio is scanning without error.
  /// Otherwise "quiet" would be a false all-clear.
  bool get isMeasuring => isScanning && errorKey == null;

  RfDetectorState copyWith({
    double? Function()? currentDbm,
    double? Function()? peakDbm,
    int? packetsPerSecond,
    int? activeTransmitters,
    String? Function()? strongestSourceName,
    bool? isScanning,
    String? Function()? hardwareNodeName,
    bool? isBuzzerEnabled,
    List<double>? history,
    RfThreatLevel? threatLevel,
    String? Function()? errorKey,
    bool? isStarting,
    bool? isBluetoothOff,
  }) {
    return RfDetectorState(
      currentDbm: currentDbm != null ? currentDbm() : this.currentDbm,
      peakDbm: peakDbm != null ? peakDbm() : this.peakDbm,
      packetsPerSecond: packetsPerSecond ?? this.packetsPerSecond,
      activeTransmitters: activeTransmitters ?? this.activeTransmitters,
      strongestSourceName: strongestSourceName != null
          ? strongestSourceName()
          : this.strongestSourceName,
      isScanning: isScanning ?? this.isScanning,
      hardwareNodeName: hardwareNodeName != null
          ? hardwareNodeName()
          : this.hardwareNodeName,
      isBuzzerEnabled: isBuzzerEnabled ?? this.isBuzzerEnabled,
      history: history ?? this.history,
      threatLevel: threatLevel ?? this.threatLevel,
      errorKey: errorKey != null ? errorKey() : this.errorKey,
      isStarting: isStarting ?? this.isStarting,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
    );
  }
}

/// Live 2.4 GHz RF activity meter built from the phone's Bluetooth radio.
class RfDetectorViewModel extends Notifier<RfDetectorState> {
  static const Duration _window = Duration(seconds: 2);
  static const int _historyLength = 40;
  static const String permissionErrorKey = 'rf_err_permission';
  static const String bluetoothOffErrorKey = 'rf_err_bluetooth_off';
  static const String scanFailedErrorKey = 'rf_err_scan_failed';
  static const String scanStartErrorKey = 'rf_err_scan_start';
  static const String noRadioErrorKey = 'rf_err_no_radio';
  static const String locationOffErrorKey = 'rf_err_location_off';
  static const String scanThrottledErrorKey = 'rf_err_scan_throttled';

  /// English reasons for the saved incident record (official record).
  static const Map<String, String> _englishReasons = {
    permissionErrorKey: 'Bluetooth/Location permission is required',
    bluetoothOffErrorKey: 'Bluetooth is off',
    scanFailedErrorKey: 'Bluetooth scan failed',
    scanStartErrorKey: 'could not start the Bluetooth scan',
    noRadioErrorKey: 'this phone has no usable Bluetooth radio',
    locationOffErrorKey: 'Location (GPS) is off',
    scanThrottledErrorKey: 'Android paused scanning (too many restarts)',
  };

  /// Translation key for a scan failure reported by the Bluetooth service.
  static String scanErrorKey(BleScanException e) {
    if (e.code == BleScanError.locationOff) return locationOffErrorKey;
    if (e.code == BleScanError.throttled) return scanThrottledErrorKey;
    return scanFailedErrorKey;
  }

  late RfRepository _repository;
  late GeigerBuzzerService _buzzer;
  bool _isBeeping = false;
  late AppLogger _logger;

  final List<RfPacket> _recent = [];
  final Map<String, DateTime> _hardwareNodes = {};
  StreamSubscription<RfPacket>? _sub;
  StreamSubscription<BleAdapterStatus>? _adapterSub;
  Timer? _ticker;
  bool _scanStarted = false;

  /// True while another screen (e.g. the incident form) covers the meter.
  bool _alertsSuspended = false;

  @override
  RfDetectorState build() {
    _repository = ref.watch(rfRepositoryProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    _logger = ref.watch(appLoggerProvider);
    ref.onDispose(_stop);
    Future.microtask(startScanning);
    return const RfDetectorState();
  }

  Future<void> startScanning() async {
    if (!ref.mounted || state.isStarting) return;
    _cancelLive();
    state = state.copyWith(
      isStarting: true,
      errorKey: () => null,
      isBluetoothOff: false,
    );

    final permission = await _repository.requestPermissions();
    if (!ref.mounted) return;
    if (permission != AppPermissionStatus.granted) {
      _notMeasuring(permissionErrorKey);
      return;
    }
    _watchAdapter();
    if (!await _repository.isBluetoothOn()) {
      _notMeasuring(bluetoothOffErrorKey, bluetoothOff: true);
      return;
    }
    if (!ref.mounted) return;

    _sub = _repository.packets().listen(
      _onPacket,
      onError: (Object e, StackTrace st) {
        _logger.warning('RF scan error', e, st);
        _notMeasuring(
          e is BleScanException ? scanErrorKey(e) : scanFailedErrorKey,
        );
      },
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());

    try {
      _scanStarted = true;
      await _repository.startScan();
    } on BleScanException catch (e) {
      _logger.warning('RF scan failed to start', e);
      _notMeasuring(scanErrorKey(e));
      return;
    } catch (e, st) {
      _logger.error('RF scan could not start', e, st);
      _notMeasuring(scanStartErrorKey);
      return;
    }
    if (ref.mounted) {
      state = state.copyWith(
        isScanning: true,
        isStarting: false,
        errorKey: () => null,
      );
    }
  }

  void stopScanning() {
    _stop();
    state = state.copyWith(isScanning: false);
  }

  /// Follows the adapter so turning Bluetooth off mid-session is shown, and
  /// measuring resumes when it comes back on.
  void _watchAdapter() {
    if (_adapterSub != null) return;
    _adapterSub = _repository.adapterStatus().listen(
      (status) {
        if (!ref.mounted) return;
        switch (status) {
          case BleAdapterStatus.on:
            if (state.isBluetoothOff) startScanning();
          case BleAdapterStatus.off:
            if (!state.isBluetoothOff) {
              _notMeasuring(bluetoothOffErrorKey, bluetoothOff: true);
            }
          case BleAdapterStatus.unauthorized:
            _notMeasuring(permissionErrorKey);
          case BleAdapterStatus.unavailable:
            _notMeasuring(noRadioErrorKey);
          case BleAdapterStatus.unknown:
            break;
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.warning('Bluetooth adapter status error', e, st);
      },
    );
  }

  /// Stops measuring and says why, so the screen never shows a stale or
  /// empty reading as "quiet".
  void _notMeasuring(String errorKey, {bool bluetoothOff = false}) {
    if (!ref.mounted) return;
    _cancelLive();
    if (_scanStarted) {
      _scanStarted = false;
      _repository.stopScan().catchError((Object e, StackTrace st) {
        _logger.warning('RF scan could not stop', e, st);
      });
    }
    _buzzer.stopBuzzer();
    state = state.copyWith(
      isScanning: false,
      isStarting: false,
      isBluetoothOff: bluetoothOff,
      errorKey: () => errorKey,
      currentDbm: () => null,
      packetsPerSecond: 0,
      activeTransmitters: 0,
      strongestSourceName: () => null,
      hardwareNodeName: () => null,
      threatLevel: RfThreatLevel.quiet,
    );
  }

  void _onPacket(RfPacket p) {
    _recent.add(p);
    if (p.isExamGuardNode) _hardwareNodes[p.sourceName] = p.timestamp;
  }

  void _tick() {
    if (!ref.mounted) return;
    final now = DateTime.now();
    _recent.removeWhere((r) => now.difference(r.timestamp) > _window);
    _hardwareNodes.removeWhere((_, seen) => now.difference(seen) > _window * 5);

    RfPacket? strongest;
    final ids = <String>{};
    var lastSecond = 0;
    for (final r in _recent) {
      ids.add(r.sourceId);
      if (now.difference(r.timestamp) <= const Duration(seconds: 1)) {
        lastSecond++;
      }
      if (strongest == null || r.rssi > strongest.rssi) strongest = r;
    }

    final dbm = strongest?.rssi.toDouble();
    final peak = dbm == null
        ? state.peakDbm
        : (state.peakDbm == null || dbm > state.peakDbm! ? dbm : state.peakDbm);
    final threat = RfThreatLevel.fromDbm(dbm);

    final history = [...state.history, dbm ?? -100.0];
    if (history.length > _historyLength) history.removeAt(0);

    if (state.isBuzzerEnabled &&
        !_alertsSuspended &&
        threat == RfThreatLevel.strong) {
      _buzzer.updateTargetDistance(1.0);
      _isBeeping = true;
    } else if (_isBeeping) {
      // Only silence beeps this screen started; the buzzer is shared with
      // the radar and magnetic screens.
      _buzzer.stopBuzzer();
      _isBeeping = false;
    }

    state = state.copyWith(
      currentDbm: () => dbm,
      peakDbm: () => peak,
      packetsPerSecond: lastSecond,
      activeTransmitters: ids.length,
      strongestSourceName: () => strongest == null
          ? null
          : (strongest.sourceName.isNotEmpty
                ? strongest.sourceName
                : strongest.sourceId),
      hardwareNodeName: () =>
          _hardwareNodes.isEmpty ? null : _hardwareNodes.keys.first,
      history: history,
      threatLevel: threat,
    );
  }

  void toggleBuzzer() {
    final next = !state.isBuzzerEnabled;
    state = state.copyWith(isBuzzerEnabled: next);
    if (!next) _buzzer.stopBuzzer();
  }

  /// Silences the buzzer while another screen is on top (e.g. the incident
  /// form). The next tick resumes it when [suspended] is false.
  void setAlertsSuspended(bool suspended) {
    _alertsSuspended = suspended;
    if (suspended) _buzzer.stopBuzzer();
  }

  void resetPeak() {
    state = state.copyWith(peakDbm: () => state.currentDbm);
  }

  /// Evidence for the incident form.
  String incidentNotes() {
    if (!state.isMeasuring) {
      final reason = _englishReasons[state.errorKey];
      return 'RF meter: not measuring when logged'
          '${reason != null ? ' ($reason)' : ''}.';
    }
    final current = state.currentDbm?.toStringAsFixed(0) ?? '--';
    final peak = state.peakDbm?.toStringAsFixed(0) ?? '--';
    final source = state.strongestSourceName ?? 'no source';
    return 'RF meter: strongest $current dBm from $source '
        '(peak $peak dBm), ${state.activeTransmitters} transmitters, '
        '${state.packetsPerSecond} packets/s, ${state.threatLevel.label}.';
  }

  void _cancelLive() {
    _ticker?.cancel();
    _ticker = null;
    _sub?.cancel();
    _sub = null;
    _recent.clear();
  }

  void _stop() {
    _cancelLive();
    _adapterSub?.cancel();
    _adapterSub = null;
    if (_scanStarted) {
      _scanStarted = false;
      _repository.stopScan().catchError((Object e, StackTrace st) {
        _logger.warning('RF scan could not stop', e, st);
      });
    }
    _buzzer.stopBuzzer();
  }
}

final rfDetectorViewModelProvider =
    NotifierProvider.autoDispose<RfDetectorViewModel, RfDetectorState>(
      RfDetectorViewModel.new,
    );
