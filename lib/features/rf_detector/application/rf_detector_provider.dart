import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/audio/geiger_buzzer_service.dart';
import '../../../core/services/bluetooth/i_bluetooth_service.dart';
import '../../../core/services/permission/i_permission_service.dart';

enum RfThreatLevel {
  quiet(
    'QUIET (below -70 dBm)',
    'No strong 2.4 GHz transmitter near the phone.',
  ),
  moderate(
    'ACTIVE TRANSMITTER NEARBY (-70 to -50 dBm)',
    'A Bluetooth transmitter is within a few metres. Sweep slowly to find it.',
  ),
  strong(
    'STRONG TRANSMITTER VERY CLOSE (above -50 dBm)',
    'A transmitting device is within about 1 metre. Inspect this desk.',
  );

  const RfThreatLevel(this.label, this.suggestion);
  final String label;
  final String suggestion;

  static RfThreatLevel fromDbm(double? dbm) {
    if (dbm == null || dbm <= -70) return RfThreatLevel.quiet;
    if (dbm <= -50) return RfThreatLevel.moderate;
    return RfThreatLevel.strong;
  }
}

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
      hardwareNodeName:
          hardwareNodeName != null ? hardwareNodeName() : this.hardwareNodeName,
      isBuzzerEnabled: isBuzzerEnabled ?? this.isBuzzerEnabled,
      history: history ?? this.history,
      threatLevel: threatLevel ?? this.threatLevel,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Live 2.4 GHz RF activity meter built from the phone's Bluetooth radio.
class RfDetectorNotifier extends Notifier<RfDetectorState> {
  static const String _scanOwner = 'rf_detector';
  static const Duration _window = Duration(seconds: 2);
  static const int _historyLength = 40;
  static const List<String> _hardwareNodeKeywords = [
    'examguard',
    'esp32',
    'rf-node',
  ];

  late IBluetoothService _bluetooth;
  late IPermissionService _permissions;

  final List<BleScanRecord> _recent = [];
  final Map<String, DateTime> _hardwareNodes = {};
  StreamSubscription<BleScanRecord>? _sub;
  Timer? _ticker;

  @override
  RfDetectorState build() {
    _bluetooth = ref.watch(bluetoothServiceProvider);
    _permissions = ref.watch(permissionServiceProvider);
    ref.onDispose(_stop);
    Future.microtask(startScanning);
    return const RfDetectorState();
  }

  Future<void> startScanning() async {
    final permission = await _permissions.requestBluetoothScan();
    if (!ref.mounted) return;
    if (permission != AppPermissionStatus.granted) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: () => 'Bluetooth/Location permission is required.',
      );
      return;
    }
    if (await _bluetooth.adapterStatus().first != BleAdapterStatus.on) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isScanning: false,
        errorMessage: () => 'Bluetooth is OFF. Turn it on to measure RF.',
      );
      return;
    }
    if (!ref.mounted) return;

    _sub?.cancel();
    _sub = _bluetooth.scanRecords.listen(_onRecord);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    await _bluetooth.startScan(_scanOwner);
    if (ref.mounted) {
      state = state.copyWith(isScanning: true, errorMessage: () => null);
    }
  }

  void stopScanning() {
    _stop();
    state = state.copyWith(isScanning: false);
  }

  void _onRecord(BleScanRecord r) {
    _recent.add(r);
    final lower = r.name.toLowerCase();
    if (_hardwareNodeKeywords.any(lower.contains)) {
      _hardwareNodes[r.name] = r.timestamp;
    }
  }

  void _tick() {
    if (!ref.mounted) return;
    final now = DateTime.now();
    _recent.removeWhere((r) => now.difference(r.timestamp) > _window);
    _hardwareNodes.removeWhere((_, seen) => now.difference(seen) > _window * 5);

    BleScanRecord? strongest;
    final ids = <String>{};
    var lastSecond = 0;
    for (final r in _recent) {
      ids.add(r.id);
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
      GeigerBuzzerService.instance.updateTargetDistance(1.0);
    } else {
      GeigerBuzzerService.instance.stopBuzzer();
    }

    state = state.copyWith(
      currentDbm: () => dbm,
      peakDbm: () => peak,
      packetsPerSecond: lastSecond,
      activeTransmitters: ids.length,
      strongestSourceName: () => strongest == null
          ? null
          : (strongest.name.isNotEmpty ? strongest.name : strongest.id),
      hardwareNodeName: () =>
          _hardwareNodes.isEmpty ? null : _hardwareNodes.keys.first,
      history: history,
      threatLevel: threat,
    );
  }

  void toggleBuzzer() {
    final next = !state.isBuzzerEnabled;
    state = state.copyWith(isBuzzerEnabled: next);
    if (!next) GeigerBuzzerService.instance.stopBuzzer();
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
    _bluetooth.stopScan(_scanOwner);
    GeigerBuzzerService.instance.stopBuzzer();
  }
}

final rfDetectorProvider =
    NotifierProvider.autoDispose<RfDetectorNotifier, RfDetectorState>(
  RfDetectorNotifier.new,
);
