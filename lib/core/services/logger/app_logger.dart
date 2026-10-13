import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';

/// App-wide logger. Wraps the `logger` package so features never import it.
class AppLogger {
  AppLogger() : _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  final Logger _logger;

  void debug(String message) => _logger.d(message);

  void info(String message) => _logger.i(message);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());
