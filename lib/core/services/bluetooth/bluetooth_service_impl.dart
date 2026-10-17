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

  /// Start/stop requests run one at a time. Overlapping calls used to start
  /// the radio twice, and Android blocks all results for 30 s after 5 scan
  /// starts in 30 s, so the list stopped updating.
  Future<void> _queue = Future.value();

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
  Future<void> startScan(String owner) {
    _owners.add(owner);
    return _serial(_sync);
  }

  @override
  Future<void> stopScan(String owner) {
    _owners.remove(owner);
    return _serial(_sync);
  }

  Future<void> _serial(Future<void> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.catchError((Object _) {});
    return result;
  }

  /// Brings the radio and subscriptions in line with [_owners].
  Future<void> _sync() async {
    if (_owners.isEmpty) {
      _restartTimer?.cancel();
      _restartTimer = null;
      await _adapterSub?.cancel();
      _adapterSub = null;
      await _resultsSub?.cancel();
      _resultsSub = null;
      await _stopRadio();
      return;
    }

    _resultsSub ??= FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final r in results) {
          _records.add(_mapResult(r));
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.warning('BLE scan stream error', e, st);
        _records.addError(_scanError(e), st);
      },
    );

    // Resume the shared scan automatically when Bluetooth comes back on.
    _adapterSub ??= FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on) {
        _serial(_sync).catchError((Object e, StackTrace st) {
          _records.addError(e, st);
        });
      }
    });

    _restartTimer ??= Timer.periodic(_scanRestartInterval, (_) {
      _serial(() async {
        if (_owners.isEmpty) return;
        await _stopRadio();
        await _startRadio();
      }).catchError((Object e, StackTrace st) {
        _records.addError(e, st);
      });
    });

    if (!FlutterBluePlus.isScanningNow) await _startRadio();
  }

  Future<void> _startRadio() async {
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
      throw _scanError(e);
    }
  }

  Future<void> _stopRadio() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e, st) {
      _logger.warning('BLE stopScan failed', e, st);
    }
  }

  BleScanException _scanError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('location')) {
      return const BleScanException(
        'Turn on Location (GPS) — Android needs it to scan for Bluetooth devices.',
        code: BleScanError.locationOff,
      );
    }
    if (text.contains('frequently')) {
      return const BleScanException(
        'Android paused scanning (too many restarts). It resumes in about 30 seconds.',
        code: BleScanError.throttled,
      );
    }
    return BleScanException('Bluetooth scan failed: $e');
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
    // Android delivers the advertisement and the scan response (which often
    // carries the name) as separate packets, so fall back to the name this
    // device advertised earlier, then to the OS-cached name.
    final name = [
      adv.advName,
      r.device.advName,
      r.device.platformName,
    ].map((n) => n.trim()).firstWhere((n) => n.isNotEmpty, orElse: () => '');
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
