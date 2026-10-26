import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/features/rf_detector/repository/rf_repository.dart';
import 'package:exam_guard/features/rf_detector/view_model/rf_detector_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FakeBluetoothService implements IBluetoothService {
  @override
  Future<Map<String, String>> knownDeviceNames() async => const {};
  final records = StreamController<BleScanRecord>.broadcast();
  final adapter = StreamController<BleAdapterStatus>.broadcast();
  BleAdapterStatus status = BleAdapterStatus.on;
  final owners = <String>{};
  BleScanException? startError;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleAdapterStatus> adapterStatus() async* {
    yield status;
    yield* adapter.stream;
  }

  @override
  Future<void> turnOn() async {}

  @override
  Stream<BleScanRecord> get scanRecords => records.stream;

  final problems = StreamController<BleScanError?>.broadcast();

  @override
  Stream<BleScanError?> get scanProblem => problems.stream;

  @override
  Future<void> startScan(String owner) async {
    if (startError != null) throw startError!;
    owners.add(owner);
  }

  @override
  Future<void> stopScan(String owner) async => owners.remove(owner);

  @override
  Future<BleConnectionInfo> connect(String deviceId) async =>
      throw Exception('not supported');

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async => records.close();
}

class GrantedPermissions implements IPermissionService {
  @override
  Future<AppPermissionStatus> requestBluetoothScan() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBluetoothService bluetooth;
  late ProviderContainer container;

  Future<void> start() async {
    container = ProviderContainer(
      overrides: [
        bluetoothServiceProvider.overrideWithValue(bluetooth),
        permissionServiceProvider.overrideWithValue(GrantedPermissions()),
      ],
    );
    container.listen(rfDetectorViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() => bluetooth = FakeBluetoothService());
  tearDown(() => container.dispose());

  test('measures when the scan starts', () async {
    await start();
    final state = container.read(rfDetectorViewModelProvider);
    expect(state.isMeasuring, isTrue);
    expect(bluetooth.owners, contains('rf_detector'));
  });

  test('startScan failure surfaces an error instead of "quiet"', () async {
    bluetooth.startError = const BleScanException('Scan failed to start.');
    await start();
    final state = container.read(rfDetectorViewModelProvider);
    expect(state.isScanning, isFalse);
    expect(state.isMeasuring, isFalse);
    expect(state.errorKey, RfDetectorViewModel.scanFailedErrorKey);
  });

  test('Bluetooth off at start is reported', () async {
    bluetooth.status = BleAdapterStatus.off;
    await start();
    final state = container.read(rfDetectorViewModelProvider);
    expect(state.isMeasuring, isFalse);
    expect(state.isBluetoothOff, isTrue);
    expect(state.errorKey, RfDetectorViewModel.bluetoothOffErrorKey);
  });

  test('Bluetooth turned off mid-session stops measuring', () async {
    await start();
    bluetooth.adapter.add(BleAdapterStatus.off);
    await pumpEventQueue();
    final state = container.read(rfDetectorViewModelProvider);
    expect(state.isMeasuring, isFalse);
    expect(state.isBluetoothOff, isTrue);
    expect(bluetooth.owners, isNot(contains('rf_detector')));

    bluetooth.adapter.add(BleAdapterStatus.on);
    await pumpEventQueue();
    expect(container.read(rfDetectorViewModelProvider).isMeasuring, isTrue);
  });

  test('scan stream errors stop measuring', () async {
    await start();
    bluetooth.records.addError(const BleScanException('Scan stopped.'));
    await pumpEventQueue();
    final state = container.read(rfDetectorViewModelProvider);
    expect(state.isMeasuring, isFalse);
    expect(state.errorKey, RfDetectorViewModel.scanFailedErrorKey);
  });

  test('Location off shows the location reason and clears by itself', () async {
    await start();
    bluetooth.problems.add(BleScanError.locationOff);
    await pumpEventQueue();
    var state = container.read(rfDetectorViewModelProvider);
    expect(state.isMeasuring, isFalse);
    expect(state.isLocationOff, isTrue);
    expect(state.errorKey, RfDetectorViewModel.locationOffErrorKey);
    expect(state.currentDbm, isNull);
    // The scan stays registered so it resumes once Location is back.
    expect(bluetooth.owners, contains('rf_detector'));

    bluetooth.problems.add(null);
    await pumpEventQueue();
    state = container.read(rfDetectorViewModelProvider);
    expect(state.isLocationOff, isFalse);
    expect(state.errorKey, isNull);
    expect(state.isMeasuring, isTrue);
  });

  test('a location scan error does not stop the scan', () async {
    await start();
    bluetooth.records.addError(
      const BleScanException('Location off', code: BleScanError.locationOff),
    );
    await pumpEventQueue();
    expect(container.read(rfDetectorViewModelProvider).isLocationOff, isTrue);
    expect(bluetooth.owners, contains('rf_detector'));

    bluetooth.problems.add(null);
    await pumpEventQueue();
    expect(container.read(rfDetectorViewModelProvider).isMeasuring, isTrue);
  });

  test('only "ExamGuard…" names are hardware nodes, never generic ESP32', () {
    expect(RfRepository.isExamGuardNodeName('ExamGuard-Node-1'), isTrue);
    expect(RfRepository.isExamGuardNodeName('examguard'), isTrue);
    expect(RfRepository.isExamGuardNodeName('ESP32-DevKit'), isFalse);
    expect(RfRepository.isExamGuardNodeName('esp32'), isFalse);
    expect(RfRepository.isExamGuardNodeName('rf-node'), isFalse);
  });
}
