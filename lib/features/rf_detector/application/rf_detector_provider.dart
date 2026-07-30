import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/audio/geiger_buzzer_service.dart';

enum RfThreatLevel {
  ambient('NORMAL AMBIENT (-85 to -70 dBm)', 'No cellular calls or heavy data traffic detected.'),
  elevated('ELEVATED RF ACTIVITY (-69 to -50 dBm)', 'Background packet burst or standby cellular poll.'),
  criticalCall('ACTIVE CELLULAR SIM CALL DETECTED! (-49 to -20 dBm)', 'High power RF transmitter active! Voice call in progress.'),
  criticalData('4G / 5G DATA BURST TRANSMISSION! (-49 to -20 dBm)', 'Heavy cellular data packets transmission detected!');

  const RfThreatLevel(this.label, this.suggestion);
  final String label;
  final String suggestion;
}

class RfDetectorState {
  final double currentDbm; // RF Signal strength in dBm (-90 to -20 dBm)
  final double peakDbm;
  final bool isScanning;
  final bool isHardwareConnected;
  final bool isBuzzerEnabled;
  final String activeBand;
  final List<double> history;
  final RfThreatLevel threatLevel;

  const RfDetectorState({
    this.currentDbm = -82.5,
    this.peakDbm = -82.5,
    this.isScanning = true,
    this.isHardwareConnected = false,
    this.isBuzzerEnabled = true,
    this.activeBand = '1800 MHz (Cellular)',
    this.history = const [-85.0, -84.0, -82.5, -83.0, -81.5, -82.0, -82.5],
    this.threatLevel = RfThreatLevel.ambient,
  });

  RfDetectorState copyWith({
    double? currentDbm,
    double? peakDbm,
    bool? isScanning,
    bool? isHardwareConnected,
    bool? isBuzzerEnabled,
    String? activeBand,
    List<double>? history,
    RfThreatLevel? threatLevel,
  }) {
    return RfDetectorState(
      currentDbm: currentDbm ?? this.currentDbm,
      peakDbm: peakDbm ?? this.peakDbm,
      isScanning: isScanning ?? this.isScanning,
      isHardwareConnected: isHardwareConnected ?? this.isHardwareConnected,
      isBuzzerEnabled: isBuzzerEnabled ?? this.isBuzzerEnabled,
      activeBand: activeBand ?? this.activeBand,
      history: history ?? this.history,
      threatLevel: threatLevel ?? this.threatLevel,
    );
  }

  static RfThreatLevel calculateThreat(double dbm, String band) {
    if (dbm > -48.0) {
      return band.contains('Data') || band.contains('5G')
          ? RfThreatLevel.criticalData
          : RfThreatLevel.criticalCall;
    } else if (dbm > -68.0) {
      return RfThreatLevel.elevated;
    } else {
      return RfThreatLevel.ambient;
    }
  }
}

final rfDetectorProvider =
    StateNotifierProvider<RfDetectorNotifier, RfDetectorState>((ref) {
  return RfDetectorNotifier();
});

class RfDetectorNotifier extends StateNotifier<RfDetectorState> {
  RfDetectorNotifier() : super(const RfDetectorState()) {
    startScanning();
  }

  Timer? _ticker;
  StreamSubscription<List<ScanResult>>? _bleScanSub;
  final math.Random _random = math.Random();

  void startScanning() {
    state = state.copyWith(isScanning: true);
    _attemptHardwareBleScan();
    _startSimulationLoop();
  }

  void _attemptHardwareBleScan() async {
    try {
      if (await FlutterBluePlus.isSupported == false) return;
      
      // Look for ESP32-S3 AD8318 Hardware Node
      _bleScanSub?.cancel();
      _bleScanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName.toLowerCase().contains('examguard') ||
              r.device.platformName.toLowerCase().contains('esp32') ||
              r.device.platformName.toLowerCase().contains('rf-node')) {
            state = state.copyWith(isHardwareConnected: true);
            break;
          }
        }
      });

      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
    } catch (_) {
      // Fallback silently to software simulation engine
    }
  }

  void _startSimulationLoop() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!state.isScanning) return;

      // Base room RF noise floor around -85.0 to -78.0 dBm
      final noise = -82.0 + (_random.nextDouble() * 5.0 - 2.5);
      final currentDbm = state.currentDbm;

      // Decay back to ambient if decaying from a simulated burst
      final nextDbm = currentDbm > -65.0
          ? (currentDbm * 0.75 + noise * 0.25)
          : noise;

      final peak = math.max(state.peakDbm, nextDbm);
      final threat = RfDetectorState.calculateThreat(nextDbm, state.activeBand);

      final newHist = List<double>.from(state.history)..add(nextDbm);
      if (newHist.length > 20) newHist.removeAt(0);

      // Trigger Geiger Audio if critical burst
      if (nextDbm > -48.0 && state.isBuzzerEnabled) {
        GeigerBuzzerService.instance.updateTargetDistance(1.2);
      } else {
        GeigerBuzzerService.instance.stopBuzzer();
      }

      state = state.copyWith(
        currentDbm: double.parse(nextDbm.toStringAsFixed(1)),
        peakDbm: double.parse(peak.toStringAsFixed(1)),
        history: newHist,
        threatLevel: threat,
      );
    });
  }

  /// Simulates an active GSM / Cellular Voice Call transmission spike (-32.5 dBm)
  void triggerSimulatedCallSpike() {
    final spikeDbm = -32.5 + (_random.nextDouble() * 6.0);
    final newHist = List<double>.from(state.history)..add(spikeDbm);
    if (newHist.length > 20) newHist.removeAt(0);

    state = state.copyWith(
      currentDbm: double.parse(spikeDbm.toStringAsFixed(1)),
      peakDbm: math.max(state.peakDbm, spikeDbm),
      activeBand: '1800 MHz (GSM Voice Call)',
      history: newHist,
      threatLevel: RfThreatLevel.criticalCall,
    );

    if (state.isBuzzerEnabled) {
      GeigerBuzzerService.instance.updateTargetDistance(0.8);
    }
  }

  /// Simulates 4G/5G High-Speed Data Packet Burst (-38.2 dBm)
  void triggerSimulatedDataBurst() {
    final burstDbm = -38.2 + (_random.nextDouble() * 5.0);
    final newHist = List<double>.from(state.history)..add(burstDbm);
    if (newHist.length > 20) newHist.removeAt(0);

    state = state.copyWith(
      currentDbm: double.parse(burstDbm.toStringAsFixed(1)),
      peakDbm: math.max(state.peakDbm, burstDbm),
      activeBand: '3500 MHz (5G NR Data Burst)',
      history: newHist,
      threatLevel: RfThreatLevel.criticalData,
    );

    if (state.isBuzzerEnabled) {
      GeigerBuzzerService.instance.updateTargetDistance(1.0);
    }
  }

  void toggleBuzzer() {
    final next = !state.isBuzzerEnabled;
    state = state.copyWith(isBuzzerEnabled: next);
    if (!next) GeigerBuzzerService.instance.stopBuzzer();
  }

  void resetPeak() {
    state = state.copyWith(peakDbm: state.currentDbm);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bleScanSub?.cancel();
    GeigerBuzzerService.instance.stopBuzzer();
    super.dispose();
  }
}
