import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/bluetooth/i_bluetooth_service.dart';
import '../../../core/services/logger/app_logger.dart';
import '../../../core/services/permission/i_permission_service.dart';
import '../domain/bluetooth_device_inspector.dart';
import '../domain/scanned_device_model.dart';

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
    return devices.where((d) => d.rssi >= roomSizePreset.rssiThreshold).toList();
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
class ScannerNotifier extends Notifier<ScannerState> {
  static const String _scanOwner = 'wireless_scanner';

  /// A device that has not advertised for this long is removed.
  static const Duration _goneAfter = Duration(seconds: 30);

  late IBluetoothService _bluetooth;
  late IPermissionService _permissions;
  late AppLogger _logger;

  StreamSubscription<BleScanRecord>? _recordsSub;
  StreamSubscription<BleAdapterStatus>? _adapterSub;
  Timer? _evictTimer;

  @override
  ScannerState build() {
    _bluetooth = ref.watch(bluetoothServiceProvider);
    _permissions = ref.watch(permissionServiceProvider);
    _logger = ref.watch(appLoggerProvider);

    ref.onDispose(_stop);

    _adapterSub = _bluetooth.adapterStatus().listen(_onAdapterStatus);
    Future.microtask(() => toggleScanning(true));
    return const ScannerState();
  }

  void _onAdapterStatus(BleAdapterStatus status) {
    if (!ref.mounted) return;
    final isOff = status != BleAdapterStatus.on;
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

    _recordsSub?.cancel();
    _recordsSub = _bluetooth.scanRecords.listen(_onRecord);
    _evictTimer?.cancel();
    _evictTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _evictStaleDevices();
    });

    await _bluetooth.startScan(_scanOwner);
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
      final info = await _bluetooth.connect(deviceId);
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
      await _bluetooth.disconnect(deviceId);
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
      await _bluetooth.turnOn();
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
      if (!await _bluetooth.isSupported()) {
        state = state.copyWith(
          errorMessage: 'Bluetooth hardware is not supported on this device',
          isBluetoothOff: true,
        );
        return false;
      }

      final permission = await _permissions.requestBluetoothScan();
      if (!ref.mounted) return false;
      switch (permission) {
        case AppPermissionStatus.permanentlyDenied:
          state = state.copyWith(
            errorMessage:
                'Bluetooth/Location permission permanently denied. Please enable in Settings.',
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

      final adapter = await _bluetooth.adapterStatus().first;
      if (!ref.mounted) return false;
      if (adapter != BleAdapterStatus.on) {
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

  void _onRecord(BleScanRecord record) {
    if (!ref.mounted) return;
    final manufacturer = BluetoothDeviceInspector.resolveManufacturer(
      record.id,
      record.manufacturerData,
    );
    final deviceType = BluetoothDeviceInspector.resolveDeviceType(
      record.name,
      manufacturer,
      record.serviceUuids,
    );

    final existing = _find(record.id);
    final name = record.name.isNotEmpty
        ? record.name
        : (existing != null && existing.name.isNotEmpty
            ? existing.name
            : _inferDeviceName(manufacturer, deviceType, record.id));

    final device = ScannedDeviceModel(
      id: record.id,
      name: name,
      manufacturer: manufacturer,
      deviceType: deviceType,
      // Light smoothing keeps the list readable without hiding movement.
      rssi: existing == null
          ? record.rssi
          : ((0.6 * record.rssi) + (0.4 * existing.rssi)).round(),
      txPower: record.txPower ?? existing?.txPower,
      isConnectable: record.isConnectable,
      serviceUuids: record.serviceUuids.isNotEmpty
          ? record.serviceUuids
          : (existing?.serviceUuids ?? const []),
      lastSeen: record.timestamp,
      firstSeen: existing?.firstSeen ?? record.timestamp,
      isConnected: existing?.isConnected ?? false,
      isConnecting: existing?.isConnecting ?? false,
      batteryLevel: existing?.batteryLevel,
      fullGattName: existing?.fullGattName,
    );

    final devices = [
      for (final d in state.devices)
        if (d.id != record.id) d,
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
      devices: [
        for (final d in state.devices) d.id == id ? update(d) : d,
      ],
    );
  }

  String _inferDeviceName(String manufacturer, String deviceType, String mac) {
    final macSuffix = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;

    if (manufacturer.contains('Apple')) {
      return 'Apple Device ($macSuffix)';
    } else if (manufacturer.contains('Samsung')) {
      return 'Samsung Device ($macSuffix)';
    } else if (manufacturer.contains('Espressif')) {
      return 'ESP32 Module ($macSuffix)';
    } else if (manufacturer.contains('Sony') || manufacturer.contains('Bose')) {
      return '$manufacturer Headset ($macSuffix)';
    } else if (deviceType.contains('Audio')) {
      return 'Wireless Earpiece ($macSuffix)';
    } else if (deviceType.contains('Wearable')) {
      return 'Smartband / Watch ($macSuffix)';
    } else {
      return 'BLE Device ($macSuffix)';
    }
  }

  void clearResults() {
    state = state.copyWith(devices: []);
  }

  void _stop({bool keepAdapterListener = false}) {
    _evictTimer?.cancel();
    _evictTimer = null;
    _recordsSub?.cancel();
    _recordsSub = null;
    _bluetooth.stopScan(_scanOwner);
    if (!keepAdapterListener) {
      _adapterSub?.cancel();
      _adapterSub = null;
    }
  }
}

final scannerProvider = NotifierProvider<ScannerNotifier, ScannerState>(
  ScannerNotifier.new,
);
