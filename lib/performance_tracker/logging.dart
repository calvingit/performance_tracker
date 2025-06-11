import 'package:logging/logging.dart';

final logger = () {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('performance_tracker');
  return logger;
}();

extension LoggerX on Logger {
  void debug(Object? message, [Object? error, StackTrace? stackTrace]) =>
      log(Level.ALL, message, error, stackTrace);
}
