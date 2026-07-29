/// Logger abstraction used by ExamGuard to avoid direct package coupling in the business layer.
abstract class ILogger {
  void debug(String message, [dynamic error, StackTrace? stackTrace]);

  void info(String message, [dynamic error, StackTrace? stackTrace]);

  void warning(String message, [dynamic error, StackTrace? stackTrace]);

  void error(String message, [dynamic error, StackTrace? stackTrace]);
}
