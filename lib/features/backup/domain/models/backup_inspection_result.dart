import '../models/backup_manifest.dart';

/// Hasil inspeksi ZIP backup sebelum diimpor.
/// Domain murni: extractDir diekspresikan sebagai path string, bukan Directory.
class BackupInspectionResult {
  final BackupManifest manifest;
  final String extractDirPath;

  const BackupInspectionResult({
    required this.manifest,
    required this.extractDirPath,
  });
}
