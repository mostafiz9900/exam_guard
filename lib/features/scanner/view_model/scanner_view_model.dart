import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';

enum RoomSizePreset {
  small('Small Room (~3m)', -75),
  medium('Standard Hall (~4.5m)', -85),
  large('Large Hall (~6.5m)', -95);

  const RoomSizePreset(this.label, this.rssiThreshold);
  final String label;
  final int rssiThreshold;
}

class ScannerState {
  final bool isScanning;
  final List<ScannedDeviceModel> devices;
  final bool isRoomBoundaryMode;
  final RoomSizePreset roomSizePreset;
  final bool isBluetoothOff;
  final String? errorMessage;

  const ScannerState({
    this.isScanning = false,
    this.devices = const [],
    this.isRoomBoundaryMode = false,
    this.roomSizePreset = RoomSizePreset.medium,
    this.isBluetoothOff = false,
    this.errorMessage,
  });

  /// Returns list filtered by Room Boundary limit when active
  List<ScannedDeviceModel> get activeDevices {
    if (!isRoomBoundaryMode) return devices;
    return devices
        .where((d) => d.rssi >= roomSizePreset.rssiThreshold)
        .toList();
  }

  /// Returns list of successfully connected target devices
  List<ScannedDeviceModel> get connectedDevices {
    return devices.where((d) => d.isConnected).toList();
  }

  ScannerState copyWith({
    bool? isScanning,
    List<ScannedDeviceModel>? devices,
    bool? isRoomBoundaryMode,
    RoomSizePreset? roomSizePreset,
    bool? isBluetoothOff,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      isRoomBoundaryMode: isRoomBoundaryMode ?? this.isRoomBoundaryMode,
      roomSizePreset: roomSizePreset ?? this.roomSizePreset,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Live BLE device discovery. Scans continuously while active; every
/// advertisement updates the list immediately.
class ScannerViewModel extends Notifier<ScannerState> {
  /// A device that has not advertised for this long is removed.
  static const Duration _goneAfter = Duration(seconds: 30);

  late ScannerRepository _repository;
  late AppLogger _logger;

  StreamSubscription<DeviceSighting>? _sightingsSub;
  StreamSubscription<bool>? _adapterSub;
  Timer? _evictTimer;

  @override
  ScannerState build() {
    _repository = ref.watch(scannerRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);

    ref.onDispose(_stop);

    _adapterSub = _repository.bluetoothOn().listen(_onBluetoothOn);
    Future.microtask(() => toggleScanning(true));
    return const ScannerState();
  }

  void _onBluetoothOn(bool isOn) {
    if (!ref.mounted) return;
    final isOff = !isOn;
    if (isOff == state.isBluetoothOff) return;
    state = state.copyWith(isBluetoothOff: isOff);
    if (isOff && state.isScanning) {
      _stop(keepAdapterListener: true);
      state = state.copyWith(isScanning: false);
    } else if (!isOff) {
      // Bluetooth came back on: resume live scanning automatically.
      toggleScanning(true);
    }
  }

  void toggleRoomBoundaryMode([bool? enabled]) {
    final nextMode = enabled ?? !state.isRoomBoundaryMode;
    state = state.copyWith(isRoomBoundaryMode: nextMode);
  }

  void setRoomSizePreset(RoomSizePreset preset) {
    state = state.copyWith(roomSizePreset: preset);
  }

  Future<void> toggleScanning([bool? enable]) async {
    final shouldScan = enable ?? !state.isScanning;
    if (!shouldScan) {
      _stop(keepAdapterListener: true);
      state = state.copyWith(isScanning: false);
      return;
    }

    if (!await checkPermissions()) {
      if (ref.mounted) state = state.copyWith(isScanning: false);
      return;
    }
    if (!ref.mounted) return;

    _sightingsSub?.cancel();
    _sightingsSub = _repository.sightings().listen(_onSighting);
    _evictTimer?.cancel();
    _evictTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _evictStaleDevices();
    });

    await _repository.startScan();
    if (ref.mounted) {
      state = state.copyWith(isScanning: true, clearError: true);
    }
  }

  void _evictStaleDevices() {
    final now = DateTime.now();
    final fresh = state.devices
        .where((d) => d.isConnected || now.difference(d.lastSeen) < _goneAfter)
        .toList();
    if (fresh.length != state.devices.length) {
      state = state.copyWith(devices: fresh);
    }
  }

  /// Connects to a device on the inspector's request and reads what it exposes.
  Future<void> probeDeviceConnection(String deviceId) async {
    final target = _find(deviceId);
    if (target == null || target.isConnected || target.isConnecting) return;

    _replace(deviceId, (d) => d.copyWith(isConnecting: true));
    try {
      final info = await _repository.connect(deviceId);
      if (!ref.mounted) return;
      _replace(
        deviceId,
        (d) => d.copyWith(
          isConnected: true,
          isConnecting: false,
          batteryLevel: info.batteryLevel,
          fullGattName: info.gattName,
        ),
      );
    } catch (e, st) {
      _logger.warning('Connect failed for $deviceId', e, st);
      if (!ref.mounted) return;
      _replace(deviceId, (d) => d.copyWith(isConnecting: false));
      state = state.copyWith(
        errorMessage: 'Could not connect to ${target.displayName}',
      );
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    try {
      await _repository.disconnect(deviceId);
    } catch (e, st) {
      _logger.warning('Disconnect failed for $deviceId', e, st);
    }
    if (!ref.mounted) return;
    _replace(
      deviceId,
      (d) => d.copyWith(isConnected: false, isConnecting: false),
    );
  }

  Future<void> enableBluetooth() async {
    try {
      await _repository.turnOnBluetooth();
      await toggleScanning(true);
    } catch (e, st) {
      _logger.warning('Turning Bluetooth on failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage: 'Please turn on Bluetooth from system settings.',
        );
      }
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (!await _repository.isSupported()) {
        state = state.copyWith(
          errorMessage: 'Bluetooth hardware is not supported on this device',
          isBluetoothOff: true,
        );
        return false;
      }

      final permission = await _repository.requestPermissions();
      if (!ref.mounted) return false;
      switch (permission) {
        case AppPermissionStatus.permanentlyDenied:
          state = state.copyWith(
            errorMessage: 'Bluetooth/Location permission permanently denied. Please enable in Settings.',
          );
          return false;
        case AppPermissionStatus.denied:
          state = state.copyWith(
            errorMessage: 'Bluetooth/Location permission is required to scan.',
          );
          return false;
        case AppPermissionStatus.granted:
          break;
      }

      final isOn = await _repository.bluetoothOn().first;
      if (!ref.mounted) return false;
      if (!isOn) {
        state = state.copyWith(
          isBluetoothOff: true,
          errorMessage: 'Bluetooth is OFF. Please turn ON Bluetooth to scan.',
        );
        return false;
      }

      state = state.copyWith(isBluetoothOff: false, clearError: true);
      return true;
    } catch (e, st) {
      _logger.error('Bluetooth permission check failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(errorMessage: 'Bluetooth check failed: $e');
      }
      return false;
    }
  }

  void _onSighting(DeviceSighting sighting) {
    if (!ref.mounted) return;
    final seen = sighting.device;
    final existing = _find(seen.id);

    final device = existing == null
        ? seen
        : seen.copyWith(
            // Keep a real advertised name over a later nameless packet.
            name: sighting.hasAdvertisedName ? seen.name : existing.name,
            // Light smoothing keeps the list readable without hiding movement.
            rssi: ((0.6 * seen.rssi) + (0.4 * existing.rssi)).round(),
            txPower: seen.txPower ?? existing.txPower,
            serviceUuids: seen.serviceUuids.isNotEmpty
                ? seen.serviceUuids
                : existing.serviceUuids,
            firstSeen: existing.firstSeen,
            isConnected: existing.isConnected,
            isConnecting: existing.isConnecting,
            batteryLevel: existing.batteryLevel,
            fullGattName: existing.fullGattName,
          );

    final devices = [
      for (final d in state.devices)
        if (d.id != seen.id) d,
      device,
    ]..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));

    state = state.copyWith(devices: devices);
  }

  ScannedDeviceModel? _find(String id) {
    for (final d in state.devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _replace(
    String id,
    ScannedDeviceModel Function(ScannedDeviceModel) update,
  ) {
    state = state.copyWith(
      devices: [for (final d in state.devices) d.id == id ? update(d) : d],
    );
  }

  void clearResults() {
    state = state.copyWith(devices: []);
  }

  void _stop({bool keepAdapterListener = false}) {
    _evictTimer?.cancel();
    _evictTimer = null;
    _sightingsSub?.cancel();
    _sightingsSub = null;
    _repository.stopScan();
    if (!keepAdapterListener) {
      _adapterSub?.cancel();
      _adapterSub = null;
    }
  }
}

final scannerViewModelProvider =
    NotifierProvider<ScannerViewModel, ScannerState>(ScannerViewModel.new);
