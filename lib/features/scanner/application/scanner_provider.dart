import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/models/device_model.dart';
import '../domain/services/bluetooth_scanner_service.dart';
import '../infrastructure/bluetooth_scanner_service.dart';

final bluetoothScannerServiceProvider = Provider<BluetoothScannerService>(
  (ref) => const FlutterBluetoothScannerService(),
);

final scannerStatusProvider = StreamProvider.autoDispose<BluetoothAvailability>(
  (ref) => ref.watch(bluetoothScannerServiceProvider).bluetoothAvailability(),
);

class ScannerState {
  const ScannerState({
    this.devices = const [],
    this.isScanning = false,
    this.minimumRssi,
  });

  final List<DeviceModel> devices;
  final bool isScanning;
  final int? minimumRssi;

  List<DeviceModel> get filteredDevices => minimumRssi == null
      ? devices
      : devices
            .where((device) => device.signalStrength >= minimumRssi!)
            .toList();

  ScannerState copyWith({
    List<DeviceModel>? devices,
    bool? isScanning,
    int? minimumRssi,
    bool clearMinimumRssi = false,
  }) => ScannerState(
    devices: devices ?? this.devices,
    isScanning: isScanning ?? this.isScanning,
    minimumRssi: clearMinimumRssi ? null : minimumRssi ?? this.minimumRssi,
  );
}

class ScannerNotifier extends AutoDisposeAsyncNotifier<ScannerState> {
  StreamSubscription<List<DeviceModel>>? _subscription;

  @override
  Future<ScannerState> build() async {
    ref.onDispose(() => _stopSubscription());
    return const ScannerState();
  }

  Future<void> startScanning() async {
    await _stopSubscription();
    await ref.read(bluetoothScannerServiceProvider).requestPermission();
    state = AsyncData(
      (state.valueOrNull ?? const ScannerState()).copyWith(isScanning: true),
    );
    _subscription = ref
        .read(bluetoothScannerServiceProvider)
        .scanDevices()
        .listen(
          (devices) {
            state = AsyncData(
              (state.valueOrNull ?? const ScannerState()).copyWith(
                devices: devices,
                isScanning: true,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) =>
              state = AsyncError(error, stackTrace),
          onDone: () {
            final current = state.valueOrNull;
            if (current != null) {
              state = AsyncData(current.copyWith(isScanning: false));
            }
          },
        );
  }

  Future<void> stopScanning() async {
    await _stopSubscription();
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(isScanning: false));
  }

  void filterByRssi(int? minimumRssi) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        minimumRssi: minimumRssi,
        clearMinimumRssi: minimumRssi == null,
      ),
    );
  }

  Future<void> _stopSubscription() async {
    await _subscription?.cancel();
    _subscription = null;
    await ref.read(bluetoothScannerServiceProvider).stopScanning();
  }
}

final scannerNotifierProvider =
    AsyncNotifierProvider.autoDispose<ScannerNotifier, ScannerState>(
      ScannerNotifier.new,
    );
