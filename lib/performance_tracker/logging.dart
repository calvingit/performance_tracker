import 'package:logging/logging.dart';

final logger = Logger('performance_tracker');

extension LoggerX on Logger {
    void debug(Object? message, [Object? error, StackTrace? stackTrace]) =>
      log(Level.ALL, message, error, stackTrace);
}