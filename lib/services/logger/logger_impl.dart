import 'package:logger/logger.dart';

import 'ilogger.dart';

/// Concrete logger implementation using the `logger` package.
class LoggerImpl implements ILogger {
  LoggerImpl() : _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  final Logger _logger;

  @override
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }
}
