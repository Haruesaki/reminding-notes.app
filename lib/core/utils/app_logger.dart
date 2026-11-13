import 'dart:developer';

/// Logger sederhana untuk aplikasi.
/// Membungkus `dart:developer.log` tanpa paket tambahan dan tanpa `print`.
/// Semua log ditulis dengan nama aplikasi "reminding" agar mudah difilter di DevTools.
class AppLogger {
  static const String _appName = 'reminding';

  /// Log pesan error dengan stack trace opsional.
  /// [error] dapat berupa Exception atau String deskriptif.
  /// [stackTrace] disertakan bila tersedia untuk debugging.
  static void error(Object error, [StackTrace? stackTrace]) {
    final message = error.toString();
    log(
      message,
      name: '$_appName.error',
      error: error,
      stackTrace: stackTrace,
      level: 1000, // SEVERE
    );
  }

  /// Log pesan peringatan (non-fatal).
  static void warning(String message) {
    log(message, name: '$_appName.warning', level: 900); // WARNING
  }

  /// Log pesan informasi umum.
  static void info(String message) {
    log(message, name: '$_appName.info', level: 800); // INFO
  }

  AppLogger._();
}
