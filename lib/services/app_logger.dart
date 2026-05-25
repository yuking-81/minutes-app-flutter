import 'dart:developer' as developer;

void appLog(String message, {Object? error, StackTrace? stackTrace}) {
  developer.log(
    message,
    name: 'MinutesApp',
    error: error,
    stackTrace: stackTrace,
  );
}
