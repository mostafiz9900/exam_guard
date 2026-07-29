/// Interface abstraction for local storage access.
///
/// This wrapper prevents direct usage of Hive in the UI layer and enables testable storage implementation.
abstract class ILocalStorage {
  Future<void> init();

  Future<void> write(String key, dynamic value);

  T? read<T>(String key);

  Future<void> delete(String key);

  bool containsKey(String key);

  Future<void> clear();
}
