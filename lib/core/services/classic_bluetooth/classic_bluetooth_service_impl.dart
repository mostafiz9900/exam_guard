import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// Classic Bluetooth discovery through the native EventChannel
/// `exam_guard/classic_bt` (see `ClassicBtDiscovery.kt`).
///
/// Each subscription to the channel runs one Android inquiry (~12 s). An
/// inquiry slows down BLE scanning, so cycles are spaced out: discover, pause
/// [_pause], repeat while any owner is active. Start/stop requests are
/// serialized like the BLE service.
///
/// Native events: `{type: found, address, name, rssi, majorDeviceClass,
/// deviceClass}` and `{type: finished, reason}` where reason is `done`,
/// `adapterOff`, `permissionDenied`, `unsupported` or `failed`. A cycle that
/// can't run (Bluetooth off, permission missing) is skipped quietly and
/// retried after the pause.
class ClassicBluetoothServiceImpl implements IClassicBluetoothService {
  ClassicBluetoothServiceImpl(
    this._logger, {
    bool? isAndroid,
    EventChannel channel = const EventChannel('exam_guard/classic_bt'),
    // ~12 s inquiry per ~57 s: classic earpieces still show within a
    // minute, while BLE scanning (alerts, live list) keeps most airtime.
    Duration pause = const Duration(seconds: 45),
    Duration cycleTimeout = const Duration(seconds: 20),
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _channel = channel,
       _pause = pause,
       _cycleTimeout = cycleTimeout;

  final AppLogger _logger;
  final bool _isAndroid;
  final EventChannel _channel;
  final Duration _pause;

  /// Safety net in case ACTION_DISCOVERY_FINISHED never arrives.
  final Duration _cycleTimeout;

  final Set<String> _owners = {};
  final Set<String> _suspenders = {};
  final StreamController<ClassicBtRecord> _records =
      StreamController<ClassicBtRecord>.broadcast();

  Future<void>? _loop;

  /// Completed to interrupt the running cycle or pause (last owner left).
  Completer<void>? _wake;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  @override
  bool get isSupported => _isAndroid;

  @override
  Stream<ClassicBtRecord> get discoveries => _records.stream;

  @override
  Future<void> start(String owner) {
    _owners.add(owner);
    return _serial(_sync);
  }

  @override
  Future<void> stop(String owner) {
    _owners.remove(owner);
    return _serial(_sync);
  }

  @override
  Future<void> suspend(String key) {
    _suspenders.add(key);
    return _serial(_sync);
  }

  @override
  Future<void> resume(String key) {
    _suspenders.remove(key);
    return _serial(_sync);
  }

  Future<void> _serial(Future<void> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.catchError((Object e, StackTrace st) {
      _logger.warning('Classic Bluetooth start/stop failed', e, st);
    });
    return result;
  }

  Future<void> _sync() async {
    if (!isSupported || _disposed) return;
    if (_active) {
      _loop ??= _runLoop();
      return;
    }
    final loop = _loop;
    if (loop == null) return;
    _interrupt();
    await loop;
  }

  void _interrupt() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  bool get _active => _owners.isNotEmpty && _suspenders.isEmpty && !_disposed;

  Future<void> _runLoop() async {
    try {
      while (_active) {
        await _runCycle();
        if (!_active) break;
        await _sleep(_pause);
      }
    } catch (e, st) {
      _logger.warning('Classic Bluetooth discovery loop failed', e, st);
    } finally {
      _loop = null;
    }
  }

  Future<void> _sleep(Duration d) async {
    final wake = _wake = Completer<void>();
    final timer = Timer(d, _interrupt);
    await wake.future;
    timer.cancel();
  }

  Future<void> _runCycle() async {
    final wake = _wake = Completer<void>();
    final finished = Completer<String>();
    void finish(String reason) {
      if (!finished.isCompleted) finished.complete(reason);
    }

    StreamSubscription<dynamic>? sub;
    try {
      sub = _channel.receiveBroadcastStream().listen(
        (event) {
          if (event is! Map) return;
          switch (event['type']) {
            case 'found':
              final record = _parse(event);
              if (record != null && !_records.isClosed) _records.add(record);
            case 'finished':
              finish(event['reason']?.toString() ?? 'done');
          }
        },
        onError: (Object e, StackTrace st) {
          _logger.warning('Classic Bluetooth discovery error', e, st);
          finish('error');
        },
        onDone: () => finish('closed'),
      );
      final reason = await Future.any<String?>([
        finished.future,
        wake.future.then((_) => null),
      ]).timeout(_cycleTimeout, onTimeout: () => 'timeout');
      if (reason != null && reason != 'done') {
        _logger.debug('Classic Bluetooth cycle skipped/ended: $reason');
      }
    } on PlatformException catch (e, st) {
      _logger.warning('Classic Bluetooth discovery failed', e, st);
    } finally {
      try {
        // Cancelling the subscription cancels the inquiry natively.
        await sub?.cancel();
      } catch (e, st) {
        _logger.warning('Classic Bluetooth cancel failed', e, st);
      }
    }
  }

  ClassicBtRecord? _parse(Map<dynamic, dynamic> event) {
    final address = event['address']?.toString().trim().toUpperCase() ?? '';
    if (address.isEmpty) return null;
    return ClassicBtRecord(
      address: address,
      name: event['name']?.toString().trim() ?? '',
      rssi: _int(event['rssi']),
      majorDeviceClass: _int(event['majorDeviceClass']),
      deviceClass: _int(event['deviceClass']),
      timestamp: DateTime.now(),
    );
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  @override
  Future<void> dispose() async {
    _owners.clear();
    await _serial(_sync);
    _disposed = true;
    await _records.close();
  }
}
