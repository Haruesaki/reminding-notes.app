import 'dart:typed_data';

import '../models/backup_inspection_result.dart';

/// Repository abstrak untuk operasi backup/restore.
/// Domain murni: tidak mengimpor dart:io, package:flutter, atau plugin.
/// Semua path diekspresikan sebagai String.
abstract class BackupRepository {
  /// Ekspor seluruh notes_data + notes_assets ke bytes ZIP.
  Future<Uint8List> exportBackup(ExportBackupParams params);

  /// Validasi ZIP backup: zip slip, manifest, checksum, parse JSON, migrasi.
  /// Mengembalikan hasil inspeksi yang berisi path direktori ekstraksi sementara.
  Future<BackupInspectionResult> inspectBackup(InspectBackupParams params);

  /// Terapkan impor backup (merge atau replaceAll) dengan rollback internal.
  Future<void> importBackup(ImportBackupParams params);
}

class ExportBackupParams {
  final String notesDirPath;
  final String assetsDirPath;

  const ExportBackupParams({
    required this.notesDirPath,
    required this.assetsDirPath,
  });
}

class InspectBackupParams {
  final List<int> zipBytes;
  final String tempExtractDirPath;

  const InspectBackupParams({
    required this.zipBytes,
    required this.tempExtractDirPath,
  });
}

class ImportBackupParams {
  final BackupInspectionResult inspection;
  final ImportMode mode;
  final String notesDirPath;
  final String assetsDirPath;
  final String tempSafetyDirPath;

  const ImportBackupParams({
    required this.inspection,
    required this.mode,
    required this.notesDirPath,
    required this.assetsDirPath,
    required this.tempSafetyDirPath,
  });
}

enum ImportMode { merge, replaceAll }
