import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thrown when a value could not be written or deleted.
class StorageException implements Exception {
  const StorageException(this.cause);

  final Object cause;

  @override
  String toString() => 'StorageException: $cause';
}

/// Key-value persistence. Features use this instead of `hive_flutter`.
abstract interface class ILocalStorage {
  /// Throws [StorageException] on failure (same for [delete]).
  Future<void> write(String key, Object? value);

  T? read<T>(String key);

  Future<void> delete(String key);

  Iterable<String> get keys;

  Future<void> dispose();
}

/// Overridden at startup with an opened [ILocalStorage]
/// (see `HiveStorageImpl.open` in main.dart).
final localStorageProvider = Provider<ILocalStorage>(
  (ref) => throw UnimplementedError(
    'Override localStorageProvider in ProviderScope at startup',
  ),
);
