import 'dart:typed_data';

import '../../../../core/usecase/usecase.dart';
import '../models/backup_inspection_result.dart';
import '../repositories/backup_repository.dart';

/// Ekspor backup: ambil bytes ZIP dari notes_data + notes_assets.
class ExportBackup implements UseCase<Uint8List, ExportBackupParams> {
  final BackupRepository repository;

  ExportBackup(this.repository);

  @override
  Future<Uint8List> call(ExportBackupParams params) {
    return repository.exportBackup(params);
  }
}

/// Inspeksi ZIP backup: validasi zip slip, manifest, checksum, parse JSON, migrasi.
class InspectBackup implements UseCase<BackupInspectionResult, InspectBackupParams> {
  final BackupRepository repository;

  InspectBackup(this.repository);

  @override
  Future<BackupInspectionResult> call(InspectBackupParams params) {
    return repository.inspectBackup(params);
  }
}

/// Impor backup dengan mode merge atau replaceAll, termasuk rollback internal.
class ImportBackup implements UseCase<void, ImportBackupParams> {
  final BackupRepository repository;

  ImportBackup(this.repository);

  @override
  Future<void> call(ImportBackupParams params) {
    return repository.importBackup(params);
  }
}
