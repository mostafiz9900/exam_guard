import 'package:hive_flutter/hive_flutter.dart';

import '../../features/scanner/domain/models/device_model.dart';
import '../../features/session/domain/models/session_model.dart';
import 'ilocal_storage.dart';

/// Hive implementation of [ILocalStorage].
///
/// This class provides a single Box-based local storage implementation for offline support.
class HiveStorageImpl implements ILocalStorage {
  HiveStorageImpl(this._boxName);

  final String _boxName;
  Box<dynamic>? _box;

  static const String sessionKey = 'current_session';
  static const String devicesKey = 'tracked_devices';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<void> write(String key, dynamic value) async {
    if (_box == null) {
      throw StateError('Hive box is not initialized. Call init() first.');
    }

    try {
      await _box!.put(key, value);
    } catch (error, stackTrace) {
      throw HiveError('Failed to write key "$key" to Hive.', error, stackTrace);
    }
  }

  @override
  T? read<T>(String key) {
    if (_box == null) {
      throw StateError('Hive box is not initialized. Call init() first.');
    }
    if (!_box!.containsKey(key)) {
      return null;
    }

    final rawValue = _box!.get(key);
    return rawValue is T ? rawValue : null;
  }

  @override
  Future<void> delete(String key) async {
    if (_box == null) {
      throw StateError('Hive box is not initialized. Call init() first.');
    }

    await _box!.delete(key);
  }

  @override
  bool containsKey(String key) {
    return _box?.containsKey(key) ?? false;
  }

  @override
  Future<void> clear() async {
    if (_box == null) {
      throw StateError('Hive box is not initialized. Call init() first.');
    }

    await _box!.clear();
  }

  Future<void> saveSession(SessionModel session) async {
    return write(sessionKey, session.toMap());
  }

  SessionModel? readSession() {
    final map = read<dynamic>(sessionKey);
    if (map is! Map<String, dynamic>) {
      return null;
    }

    try {
      return SessionModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDevices(List<DeviceModel> devices) async {
    final payload = devices.map((device) => device.toMap()).toList();
    return write(devicesKey, payload);
  }

  List<DeviceModel> readDevices() {
    final raw = read<dynamic>(devicesKey);
    if (raw is! List<dynamic>) {
      return <DeviceModel>[];
    }

    try {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(DeviceModel.fromMap)
          .toList();
    } catch (_) {
      return <DeviceModel>[];
    }
  }
}

class HiveError implements Exception {
  HiveError(this.message, this.originalError, this.stackTrace);

  final String message;
  final Object originalError;
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'HiveError: $message - $originalError';
  }
}
