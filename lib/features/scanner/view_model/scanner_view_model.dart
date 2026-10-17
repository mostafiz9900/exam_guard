import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';

enum RoomSizePreset {
  small('scan_room_small', -75),
  medium('scan_room_medium', -85),
  large('scan_room_large', -95);

  const RoomSizePreset(this.labelKey, this.rssiThreshold);

  /// Translation key of the preset's display name.
  final String labelKey;
  final int rssiThreshold;
}

class ScannerState {
  final bool isScanning;
  final List<ScannedDeviceModel> devices;
  final bool isRoomBoundaryMode;
  final RoomSizePreset roomSizePreset;
  final bool isBluetoothOff;

  /// Translation key of the current error, or null when there is none.
  final String? errorMessage;

  /// Placeholder values for [errorMessage].
  final Map<String, String> errorArgs;

  const ScannerState({
    this.isScanning = false,
    this.devices = const [],
    this.isRoomBoundaryMode = false,
    this.roomSizePreset = RoomSizePreset.medium,
    this.isBluetoothOff = false,
    this.errorMessage,
    this.errorArgs = const {},
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
    Map<String, String>? errorArgs,
    bool clearError = false,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      isRoomBoundaryMode: isRoomBoundaryMode ?? this.isRoomBoundaryMode,
      roomSizePreset: roomSizePreset ?? this.roomSizePreset,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorArgs: clearError
          ? const {}
          : (errorArgs ?? (errorMessage != null ? const {} : this.errorArgs)),
    );
  }
}

/// Live BLE device discovery. Scans continuously while active; every
/// advertisement updates the list immediately.
class ScannerViewModel extends Notifier<ScannerState> {
  /// A device that has not advertised for this long is removed.
  static const Duration _goneAfter = Duration(seconds: 30);

  /// Phones, watches and earbuds change their random BLE address every few
  /// minutes. An entry silent for this long that looks exactly like a newly
  /// appeared address is treated as the same device.
  static const Duration _rotationGap = Duration(seconds: 5);

  late ScannerRepository _repository;
  late AppLogger _logger;

  StreamSubscription<ScannedDeviceModel>? _sightingsSub;
  StreamSubscription<bool>? _adapterSub;
  Timer? _evictTimer;
  Future<void>? _starting;

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
    // The view model, the screen and the adapter listener can all ask to
    // start at once; share one start so permissions are requested only once.
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    if (!await checkPermissions()) {
      if (ref.mounted) state = state.copyWith(isScanning: false);
      return;
    }
    if (!ref.mounted) return;

    _sightingsSub?.cancel();
    _sightingsSub = _repository.sightings().listen(
      _onSighting,
      onError: (Object e, StackTrace st) {
        _logger.warning('BLE scan error', e, st);
        if (ref.mounted) _setScanError(e);
      },
    );
    _evictTimer?.cancel();
    _evictTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _evictStaleDevices();
    });

    try {
      await _repository.startScan();
    } on BleScanException catch (e) {
      if (!ref.mounted) return;
      _stop(keepAdapterListener: true);
      state = state.copyWith(isScanning: false);
      _setScanError(e);
      return;
    }
    if (ref.mounted) {
      state = state.copyWith(isScanning: true, clearError: true);
    }
  }

  /// Maps a scan failure to a translatable message. Known core messages get
  /// their own key; anything else is shown as reported.
  void _setScanError(Object e) {
    final text = e is BleScanException ? e.message : '$e';
    final code = e is BleScanException ? e.code : BleScanError.other;
    if (code == BleScanError.locationOff) {
      state = state.copyWith(errorMessage: 'scan_err_location');
    } else if (code == BleScanError.throttled) {
      state = state.copyWith(errorMessage: 'scan_err_throttled');
    } else {
      state = state.copyWith(
        errorMessage: 'scan_err_detail',
        errorArgs: {'detail': text},
      );
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
        errorMessage: 'scan_err_connect_failed',
        errorArgs: {'name': target.displayName},
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
        state = state.copyWith(errorMessage: 'scan_err_enable_bluetooth');
      }
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (!await _repository.isSupported()) {
        state = state.copyWith(
          errorMessage: 'scan_err_unsupported',
          isBluetoothOff: true,
        );
        return false;
      }

      final permission = await _repository.requestPermissions();
      if (!ref.mounted) return false;
      switch (permission) {
        case AppPermissionStatus.permanentlyDenied:
          state = state.copyWith(errorMessage: 'scan_err_permission_permanent');
          return false;
        case AppPermissionStatus.denied:
          state = state.copyWith(errorMessage: 'scan_err_permission_required');
          return false;
        case AppPermissionStatus.granted:
          break;
      }

      final isOn = await _repository.bluetoothOn().first;
      if (!ref.mounted) return false;
      if (!isOn) {
        state = state.copyWith(
          isBluetoothOff: true,
          errorMessage: 'scan_err_bluetooth_off',
        );
        return false;
      }

      state = state.copyWith(isBluetoothOff: false, clearError: true);
      return true;
    } catch (e, st) {
      _logger.error('Bluetooth permission check failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage: 'scan_err_check_failed',
          errorArgs: {'detail': '$e'},
        );
      }
      return false;
    }
  }

  void _onSighting(ScannedDeviceModel seen) {
    if (!ref.mounted) return;
    final existing = _find(seen.id);
    final rotatedFrom = existing == null ? _rotatedFrom(seen) : null;
    final previous = existing ?? rotatedFrom;

    final device = previous == null
        ? seen
        : seen.copyWith(
            // Light smoothing keeps the list readable without hiding movement.
            rssi: existing == null
                ? seen.rssi
                : ((0.6 * seen.rssi) + (0.4 * existing.rssi)).round(),
            isConnectable: seen.isConnectable || previous.isConnectable,
            firstSeen: previous.firstSeen,
            isConnected: existing?.isConnected,
            isConnecting: existing?.isConnecting,
            batteryLevel: existing?.batteryLevel,
            fullGattName: existing?.fullGattName,
          );

    final devices = [
      for (final d in state.devices)
        if (d.id != seen.id && d.id != rotatedFrom?.id) d,
      device,
    ]..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));

    state = state.copyWith(devices: devices);
  }

  /// The entry a newly seen address most likely replaced: same name (or,
  /// for nameless devices, same vendor, category and services) and silent
  /// since before [_rotationGap]. Two identical devices that are both
  /// advertising are never merged.
  ScannedDeviceModel? _rotatedFrom(ScannedDeviceModel seen) {
    final now = DateTime.now();
    ScannedDeviceModel? match;
    for (final d in state.devices) {
      if (d.isConnected || d.isConnecting) continue;
      if (now.difference(d.lastSeen) < _rotationGap) continue;
      final sameIdentity = seen.hasName || d.hasName
          ? seen.name.trim() == d.name.trim()
          : seen.manufacturer == d.manufacturer &&
                seen.manufacturer != 'Generic BLE Hardware' &&
                seen.deviceType == d.deviceType &&
                _sameServices(seen.serviceUuids, d.serviceUuids);
      if (sameIdentity &&
          (match == null || d.lastSeen.isAfter(match.lastSeen))) {
        match = d;
      }
    }
    return match;
  }

  static bool _sameServices(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

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

/// Auto-disposed so the BLE scan stops once the dashboard and scanner
/// screens are gone (e.g. after End Exam).
final scannerViewModelProvider =
    NotifierProvider.autoDispose<ScannerViewModel, ScannerState>(
      ScannerViewModel.new,
    );
