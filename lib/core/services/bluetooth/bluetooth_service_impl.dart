import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';

class BluetoothServiceImpl implements IBluetoothService {
  BluetoothServiceImpl(this._logger);

  final AppLogger _logger;

  /// flutter_blue_plus requires a license tier for GATT connections.
  /// Commercial use needs a paid `License.commercial` — see the package LICENSE.
  static const License _license = License.nonprofit;

  /// Android silently downgrades scans older than 30 minutes, so restart
  /// the scan well before that.
  static const Duration _scanRestartInterval = Duration(minutes: 10);

  final Set<String> _owners = {};
  final StreamController<BleScanRecord> _records =
      StreamController<BleScanRecord>.broadcast();
  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  Timer? _restartTimer;

  @override
  Future<bool> isSupported() => FlutterBluePlus.isSupported;

  @override
  Stream<BleAdapterStatus> adapterStatus() =>
      FlutterBluePlus.adapterState.map(_mapAdapterState);

  @override
  Future<void> turnOn() => FlutterBluePlus.turnOn();

  @override
  Stream<BleScanRecord> get scanRecords => _records.stream;

  @override
  Future<void> startScan(String owner) async {
    final wasIdle = _owners.isEmpty;
    _owners.add(owner);
    if (!wasIdle) return;

    _resultsSub ??= FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final r in results) {
          _records.add(_mapResult(r));
        }
      },
      onError: (Object e, StackTrace st) =>
          _logger.warning('BLE scan stream error', e, st),
    );

    // Resume the shared scan automatically when Bluetooth comes back on.
    _adapterSub ??= FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on && _owners.isNotEmpty) {
        _startRadio();
      }
    });

    await _startRadio();
    _restartTimer?.cancel();
    _restartTimer = Timer.periodic(_scanRestartInterval, (_) async {
      if (_owners.isEmpty) return;
      await _stopRadio();
      await _startRadio();
    });
  }

  @override
  Future<void> stopScan(String owner) async {
    _owners.remove(owner);
    if (_owners.isNotEmpty) return;
    _restartTimer?.cancel();
    _restartTimer = null;
    await _adapterSub?.cancel();
    _adapterSub = null;
    await _resultsSub?.cancel();
    _resultsSub = null;
    await _stopRadio();
  }

  Future<void> _startRadio() async {
    if (FlutterBluePlus.isScanningNow) return;
    try {
      // oneByOne + continuousUpdates: every advertisement is delivered as it
      // arrives, so RSSI updates are real time.
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        oneByOne: true,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );
    } catch (e, st) {
      _logger.warning('BLE startScan failed', e, st);
    }
  }

  Future<void> _stopRadio() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e, st) {
      _logger.warning('BLE stopScan failed', e, st);
    }
  }

  @override
  Future<BleConnectionInfo> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect(
      license: _license,
      timeout: const Duration(seconds: 8),
    );

    int? battery;
    try {
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.str.toUpperCase() != '180F') continue;
        for (final c in s.characteristics) {
          if (c.uuid.str.toUpperCase() == '2A19' && c.properties.read) {
            final value = await c.read();
            if (value.isNotEmpty) battery = value.first;
          }
        }
      }
    } catch (e, st) {
      _logger.warning('GATT discovery failed for $deviceId', e, st);
    }

    final name = device.platformName.trim();
    return BleConnectionInfo(
      batteryLevel: battery,
      gattName: name.isEmpty ? null : name,
    );
  }

  @override
  Future<void> disconnect(String deviceId) =>
      BluetoothDevice.fromId(deviceId).disconnect();

  @override
  Future<void> dispose() async {
    _owners.clear();
    _restartTimer?.cancel();
    await _adapterSub?.cancel();
    await _resultsSub?.cancel();
    await _stopRadio();
    await _records.close();
  }

  BleScanRecord _mapResult(ScanResult r) {
    final adv = r.advertisementData;
    final name = adv.advName.trim().isNotEmpty
        ? adv.advName.trim()
        : r.device.platformName.trim();
    return BleScanRecord(
      id: r.device.remoteId.str.trim().toUpperCase(),
      name: name,
      rssi: r.rssi,
      txPower: adv.txPowerLevel,
      isConnectable: adv.connectable,
      serviceUuids: adv.serviceUuids.map((u) => u.str.toUpperCase()).toList(),
      manufacturerData: adv.manufacturerData,
      timestamp: r.timeStamp,
    );
  }

  BleAdapterStatus _mapAdapterState(BluetoothAdapterState s) => switch (s) {
    BluetoothAdapterState.on => BleAdapterStatus.on,
    BluetoothAdapterState.off ||
    BluetoothAdapterState.turningOff ||
    BluetoothAdapterState.turningOn => BleAdapterStatus.off,
    BluetoothAdapterState.unauthorized => BleAdapterStatus.unauthorized,
    BluetoothAdapterState.unavailable => BleAdapterStatus.unavailable,
    BluetoothAdapterState.unknown => BleAdapterStatus.unknown,
  };
}
