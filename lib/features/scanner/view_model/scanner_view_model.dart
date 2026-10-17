import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';
import 'package:exam_guard/features/scanner/view_model/device_filter.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';

export 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
export 'package:exam_guard/features/scanner/view_model/device_filter.dart';

enum RoomSizePreset {
  small('scan_room_small', -75),
  medium('scan_room_medium', -85),
  large('scan_room_large', -95);

  const RoomSizePreset(this.labelKey, this.rssiThreshold);

  /// Translation key of the preset's display name.
  final String labelKey;
  final int rssiThreshold;
}

/// Why the scanner list is empty, so the screen can say what to do.
enum ScannerEmptyReason {
  /// Android needs Location on to return BLE results.
  locationOff,
  bluetoothOff,

  /// A blocking problem in [ScannerState.errorMessage].
  error,

  /// Scanning, nothing has advertised yet.
  waiting,

  /// Scanning is stopped and nothing was found.
  paused,

  /// Devices were found but the room boundary hides all of them.
  outsideBoundary,

  /// Devices are in range but the selected filter matches none.
  filteredOut,
}

class ScannerState {
  ScannerState({
    this.isScanning = false,
    this.devices = const [],
    this.isRoomBoundaryMode = false,
    this.roomSizePreset = RoomSizePreset.medium,
    this.isBluetoothOff = false,
    this.isLocationOff = false,
    this.errorMessage,
    this.errorArgs = const {},
    this.noticeKey,
    this.noticeArgs = const {},
    this.noticeId = 0,
  });

  /// True while the scan owner is registered. It stays true while
  /// [isLocationOff]; the scan then resumes by itself.
  final bool isScanning;

  /// Every address heard recently (one entry per BLE address).
  final List<ScannedDeviceModel> devices;
  final bool isRoomBoundaryMode;
  final RoomSizePreset roomSizePreset;
  final bool isBluetoothOff;

  /// Location (GPS) is off, so Android returns no BLE results. The scan
  /// keeps its place and resumes once Location is turned on.
  final bool isLocationOff;

  /// Translation key of a blocking scan problem (permission, Bluetooth
  /// off/unsupported, scan failed), or null when scanning can work.
  final String? errorMessage;

  /// Placeholder values for [errorMessage].
  final Map<String, String> errorArgs;

  /// Translation key of the latest one-off message (e.g. a failed
  /// connection) to show once, e.g. in a snackbar. Never blocks scanning.
  final String? noticeKey;

  /// Placeholder values for [noticeKey].
  final Map<String, String> noticeArgs;

  /// Increases with every new notice, so a repeated identical notice can
  /// still be told apart from the previous one.
  final int noticeId;

  /// Devices left after the room boundary filter (one per address).
  late final List<ScannedDeviceModel> activeDevices = isRoomBoundaryMode
      ? devices.where((d) => d.rssi >= roomSizePreset.rssiThreshold).toList()
      : devices;

  /// [devices] with addresses that likely belong to one device grouped.
  late final List<ScannedDeviceGroup> groups = groupLikelySameDevices(devices);

  /// [groups] after the room boundary filter; members outside the
  /// boundary are left out of each group.
  late final List<ScannedDeviceGroup> activeGroups = isRoomBoundaryMode
      ? [
          for (final g in groups)
            if (g.members.any(_insideBoundary))
              ScannedDeviceGroup(g.members.where(_insideBoundary).toList()),
        ]
      : groups;

  bool _insideBoundary(ScannedDeviceModel d) =>
      d.rssi >= roomSizePreset.rssiThreshold;

  /// Returns list of successfully connected target devices
  List<ScannedDeviceModel> get connectedDevices {
    return devices.where((d) => d.isConnected).toList();
  }

  /// Groups shown for [filter]; a group is matched on its primary.
  List<ScannedDeviceGroup> visibleGroups(DeviceFilter filter) => [
    for (final g in activeGroups)
      if (filter.matches(g.primary)) g,
  ];

  /// Why nothing is shown for [filter], or null when something is.
  ScannerEmptyReason? emptyReason(DeviceFilter filter) {
    if (visibleGroups(filter).isNotEmpty) return null;
    if (isLocationOff) return ScannerEmptyReason.locationOff;
    if (isBluetoothOff) return ScannerEmptyReason.bluetoothOff;
    if (errorMessage != null) return ScannerEmptyReason.error;
    if (devices.isEmpty) {
      return isScanning
          ? ScannerEmptyReason.waiting
          : ScannerEmptyReason.paused;
    }
    if (activeDevices.isEmpty) return ScannerEmptyReason.outsideBoundary;
    return ScannerEmptyReason.filteredOut;
  }

  ScannerState copyWith({
    bool? isScanning,
    List<ScannedDeviceModel>? devices,
    bool? isRoomBoundaryMode,
    RoomSizePreset? roomSizePreset,
    bool? isBluetoothOff,
    bool? isLocationOff,
    String? errorMessage,
    Map<String, String>? errorArgs,
    bool clearError = false,
    String? noticeKey,
    Map<String, String>? noticeArgs,
    int? noticeId,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      isRoomBoundaryMode: isRoomBoundaryMode ?? this.isRoomBoundaryMode,
      roomSizePreset: roomSizePreset ?? this.roomSizePreset,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
      isLocationOff: isLocationOff ?? this.isLocationOff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorArgs: clearError
          ? const {}
          : (errorArgs ?? (errorMessage != null ? const {} : this.errorArgs)),
      noticeKey: noticeKey ?? this.noticeKey,
      noticeArgs:
          noticeArgs ?? (noticeKey != null ? const {} : this.noticeArgs),
      noticeId: noticeId ?? this.noticeId,
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
  StreamSubscription<BleScanError?>? _problemSub;
  Timer? _evictTimer;
  Future<void>? _starting;

  @override
  ScannerState build() {
    _repository = ref.watch(scannerRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);

    ref.onDispose(_stop);

    _adapterSub = _repository.bluetoothOn().listen(_onBluetoothOn);
    _problemSub = _repository.scanProblem().listen(
      _onScanProblem,
      onError: (Object e, StackTrace st) =>
          _logger.warning('BLE scan problem stream failed', e, st),
    );
    Future.microtask(() => toggleScanning(true));
    return ScannerState();
  }

  /// Location off: Android silently returns no BLE results. The scan owner
  /// stays registered so the shared scan resumes once Location is back.
  void _onScanProblem(BleScanError? problem) {
    if (!ref.mounted) return;
    final isOff = problem == BleScanError.locationOff;
    if (isOff == state.isLocationOff) return;
    state = state.copyWith(isLocationOff: isOff);
  }

  /// Opens the system Location settings so the user can turn Location on.
  Future<void> openLocationSettings() async {
    try {
      final opened = await _repository.openLocationSettings();
      if (!opened && ref.mounted) _notify('scan_notice_location_settings');
    } catch (e, st) {
      _logger.warning('Opening Location settings failed', e, st);
      if (ref.mounted) _notify('scan_notice_location_settings');
    }
  }

  /// Shows a one-off message without touching the blocking scan error.
  void _notify(String key, [Map<String, String> args = const {}]) {
    state = state.copyWith(
      noticeKey: key,
      noticeArgs: args,
      noticeId: state.noticeId + 1,
    );
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
      if (e.code == BleScanError.locationOff) {
        // Not a failure: the owner stays registered and the scan resumes
        // by itself once Location is turned on.
        state = state.copyWith(
          isScanning: true,
          isLocationOff: true,
          clearError: true,
        );
        return;
      }
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
  /// their own key; anything else is shown as reported. Location off is
  /// not an error: it is shown through [ScannerState.isLocationOff].
  void _setScanError(Object e) {
    final text = e is BleScanException ? e.message : '$e';
    final code = e is BleScanException ? e.code : BleScanError.other;
    if (code == BleScanError.locationOff) {
      state = state.copyWith(isLocationOff: true);
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
      _notify('scan_err_connect_failed', {'name': target.displayName});
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
      if (ref.mounted) _notify('scan_err_enable_bluetooth');
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
      _problemSub?.cancel();
      _problemSub = null;
    }
  }
}

/// Auto-disposed so the BLE scan stops once the dashboard and scanner
/// screens are gone (e.g. after End Exam).
final scannerViewModelProvider =
    NotifierProvider.autoDispose<ScannerViewModel, ScannerState>(
      ScannerViewModel.new,
    );
