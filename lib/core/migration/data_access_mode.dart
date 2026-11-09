import 'package:flutter/foundation.dart';

import '../error/failures.dart';

/// Mengelola status akses data aplikasi saat ini (normal, baca-saja karena skema lebih baru,
/// atau error migrasi saat startup).
class DataAccessMode extends ChangeNotifier {
  bool _isReadOnly = false;
  int? _newerSchemaVersion;
  String? _migrationError;

  bool get isReadOnly => _isReadOnly;
  int? get newerSchemaVersion => _newerSchemaVersion;
  String? get migrationError => _migrationError;
  bool get hasMigrationError => _migrationError != null;

  void markReadOnly({int? detectedVersion}) {
    final shouldNotify = !_isReadOnly ||
        (detectedVersion != null &&
            (_newerSchemaVersion == null || detectedVersion > _newerSchemaVersion!));
    _isReadOnly = true;
    if (detectedVersion != null &&
        (_newerSchemaVersion == null || detectedVersion > _newerSchemaVersion!)) {
      _newerSchemaVersion = detectedVersion;
    }
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void setMigrationError(String error) {
    _migrationError = error;
    notifyListeners();
  }

  void ensureWritable() {
    if (_isReadOnly) {
      throw ReadOnlyDataException(
        'Data dibuat oleh versi aplikasi yang lebih baru. Mode baca saja.',
        _newerSchemaVersion,
      );
    }
  }

  void reset() {
    final hadState = _isReadOnly || _newerSchemaVersion != null || _migrationError != null;
    _isReadOnly = false;
    _newerSchemaVersion = null;
    _migrationError = null;
    if (hadState) {
      notifyListeners();
    }
  }
}
