/// Pengecualian ketika ZIP memuat path berbahaya / path traversal (zip slip)
class DangerousPathException implements Exception {
  final String path;
  const DangerousPathException(this.path);

  @override
  String toString() =>
      'DangerousPathException: Terdeteksi path berbahaya dalam file backup: $path';
}

/// Pengecualian ketika manifest.json tidak ditemukan atau tidak valid
class InvalidBackupException implements Exception {
  final String message;
  const InvalidBackupException(this.message);

  @override
  String toString() => 'InvalidBackupException: $message';
}

/// Pengecualian ketika satu atau lebih file dalam backup corrupt / checksum tidak cocok
class CorruptedBackupException implements Exception {
  final List<String> corruptedFiles;
  const CorruptedBackupException(this.corruptedFiles);

  @override
  String toString() =>
      'CorruptedBackupException: File backup rusak atau tidak valid: ${corruptedFiles.join(', ')}';
}
