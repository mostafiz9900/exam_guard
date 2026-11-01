import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:exam_guard/core/services/bluetooth/i_ble_gatt.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

class BleGattImpl implements IBleGatt {
  BleGattImpl(this._logger);

  final AppLogger _logger;

  /// Same license tier as [BluetoothServiceImpl].
  static const License _license = License.nonprofit;

  @override
  Future<BleGattLink> open(
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final device = BluetoothDevice.fromId(deviceId);
    try {
      await device.connect(license: _license, timeout: timeout);
      final services = await device.discoverServices();
      return _Link(device, services, _logger);
    } catch (e, st) {
      _logger.warning('GATT open failed for $deviceId', e, st);
      unawaited(device.disconnect().catchError((_) {}));
      throw BleGattException('$e');
    }
  }
}

class _Link implements BleGattLink {
  _Link(this._device, this._services, this._logger) {
    _stateSub = _device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) _finish();
    });
  }

  final BluetoothDevice _device;
  final List<BluetoothService> _services;
  final AppLogger _logger;
  final Completer<void> _done = Completer<void>();
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  BluetoothCharacteristic _find(String service, String characteristic) {
    final s = Guid(service);
    final c = Guid(characteristic);
    for (final svc in _services) {
      if (svc.uuid != s) continue;
      for (final ch in svc.characteristics) {
        if (ch.uuid == c) return ch;
      }
    }
    throw BleGattException('No characteristic $characteristic');
  }

  Future<T> _guard<T>(String what, Future<T> Function() op) async {
    try {
      return await op();
    } on BleGattException {
      rethrow;
    } catch (e, st) {
      _logger.warning('GATT $what failed', e, st);
      throw BleGattException('$e');
    }
  }

  @override
  Future<List<int>> read(String service, String characteristic) =>
      _guard('read', () => _find(service, characteristic).read());

  @override
  Future<void> write(String service, String characteristic, List<int> value) =>
      _guard(
        'write',
        () => _find(service, characteristic).write(value, allowLongWrite: true),
      );

  @override
  Stream<List<int>> notifications(String service, String characteristic) {
    late final StreamController<List<int>> out;
    StreamSubscription<List<int>>? sub;
    out = StreamController<List<int>>(
      onListen: () async {
        try {
          final c = _find(service, characteristic);
          sub = c.onValueReceived.listen(out.add);
          await c.setNotifyValue(true);
        } catch (e) {
          out.addError(BleGattException('$e'));
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<void> get done => _done.future;

  void _finish() {
    _stateSub?.cancel();
    _stateSub = null;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> close() async {
    try {
      await _device.disconnect();
    } catch (_) {
      // Already gone.
    }
    _finish();
  }
}
