import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';
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
  final String? errorMessage;

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
    this.errorMessage,
  });

  bool get isHardwareNodeNearby => hardwareNodeName != null;

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
    String? Function()? errorMessage,
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
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Live 2.4 GHz RF activity meter built from the phone's Bluetooth radio.
class RfDetectorViewModel extends Notifier<RfDetectorState> {
  static const Duration _window = Duration(seconds: 2);
  static const int _historyLength = 40;
  late RfRepository _repository;
  late GeigerBuzzerService _buzzer;

  final List<RfPacket> _recent = [];
  final Map<String, DateTime> _hardwareNodes = {};
  StreamSubscription<RfPacket>? _sub;
  Timer? _ticker;

  @override
  RfDetectorState build() {
    _repository = ref.watch(rfRepositoryProvider);
    _buzzer = ref.watch(geigerBuzzerProvider);
    ref.onDispose(_stop);
    Future.microtask(startScanning);
    return const RfDetectorState();
  }

  Future<void> startScanning() async {
    final permission = await _repository.requestPermissions();
    if (!ref.mounted) return;
    if (permission != AppPermissionStatus.granted) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: () => 'Bluetooth/Location permission is required.',
      );
      return;
    }
    if (!await _repository.isBluetoothOn()) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isScanning: false,
        errorMessage: () => 'Bluetooth is OFF. Turn it on to measure RF.',
      );
      return;
    }
    if (!ref.mounted) return;

    _sub?.cancel();
    _sub = _repository.packets().listen(_onPacket);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    await _repository.startScan();
    if (ref.mounted) {
      state = state.copyWith(isScanning: true, errorMessage: () => null);
    }
  }

  void stopScanning() {
    _stop();
    state = state.copyWith(isScanning: false);
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

    if (state.isBuzzerEnabled && threat == RfThreatLevel.strong) {
      _buzzer.updateTargetDistance(1.0);
    } else {
      _buzzer.stopBuzzer();
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

  void resetPeak() {
    state = state.copyWith(peakDbm: () => state.currentDbm);
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _sub?.cancel();
    _sub = null;
    _recent.clear();
    _repository.stopScan();
    _buzzer.stopBuzzer();
  }
}

final rfDetectorViewModelProvider =
    NotifierProvider.autoDispose<RfDetectorViewModel, RfDetectorState>(
      RfDetectorViewModel.new,
    );
