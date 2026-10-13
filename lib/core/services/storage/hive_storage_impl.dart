import 'package:hive_flutter/hive_flutter.dart';

import 'package:exam_guard/core/services/storage/i_local_storage.dart';

class HiveStorageImpl implements ILocalStorage {
  HiveStorageImpl._(this._box);

  static const _boxName = 'exam_guard_storage';
  final Box<dynamic> _box;

  /// Initializes Hive and opens the app's storage box.
  static Future<HiveStorageImpl> open() async {
    await Hive.initFlutter();
    return HiveStorageImpl._(await Hive.openBox<dynamic>(_boxName));
  }

  @override
  Future<void> write(String key, Object? value) => _box.put(key, value);

  @override
  T? read<T>(String key) {
    final value = _box.get(key);
    return value is T ? value : null;
  }

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Iterable<String> get keys => _box.keys.whereType<String>();

  @override
  Future<void> dispose() => _box.close();
}
