import 'dart:io';
import 'dart:typed_data';

import 'package:reminding/core/constants/app_constants.dart';
import 'package:reminding/core/migration/data_access_mode.dart';
import 'package:reminding/core/migration/migration_runner.dart';
import 'package:reminding/features/explorer/data/datasources/notes_index_manager.dart';
import 'package:reminding/features/notes/data/datasources/tones_local_data_source.dart';
import 'package:reminding/features/notes/domain/services/reminder_sync_service.dart';
import 'package:reminding/features/backup/domain/models/backup_inspection_result.dart';
import 'package:reminding/features/backup/domain/models/backup_manifest.dart';
import 'package:reminding/features/backup/domain/repositories/backup_repository.dart';
import 'package:reminding/features/backup/domain/usecases/backup_usecases.dart';
import 'package:reminding/features/backup/data/services/backup_service.dart';

/// Implementasi konkret BackupRepository yang mendegarkan ke BackupService.
/// Berada di data layer: boleh mengimpor dart:io dan plugin.
class BackupRepositoryImpl implements BackupRepository {
  final BackupService _backupService;
  final DataAccessMode? _dataAccessMode;
  final NotesIndexManager? _indexManager;
  final TonesLocalDataSource? _tonesDataSource;
  final ReminderSyncService? _reminderSyncService;

  BackupRepositoryImpl({
    required BackupService backupService,
    DataAccessMode? dataAccessMode,
    NotesIndexManager? indexManager,
    TonesLocalDataSource? tonesDataSource,
    ReminderSyncService? reminderSyncService,
  })  : _backupService = backupService,
        _dataAccessMode = dataAccessMode,
        _indexManager = indexManager,
        _tonesDataSource = tonesDataSource,
        _reminderSyncService = reminderSyncService;

  @override
  Future<Uint8List> exportBackup(ExportBackupParams params) async {
    final notesDir = Directory(params.notesDirPath);
    final assetsDir = Directory(params.assetsDirPath);
    return _backupService.createBackup(
      notesDir: notesDir,
      assetsDir: assetsDir,
    );
  }

  @override
  Future<BackupInspectionResult> inspectBackup(InspectBackupParams params) async {
    final tempExtractDir = Directory(params.tempExtractDirPath);
    final result = await _backupService.inspectBackup(
      zipBytes: params.zipBytes,
      tempExtractDir: tempExtractDir,
    );
    return BackupInspectionResult(
      manifest: result.manifest,
      extractDirPath: tempExtractDir.path,
    );
  }

  @override
  Future<void> importBackup(ImportBackupParams params) async {
    final extractDir = Directory(params.inspection.extractDirPath);
    final notesDir = Directory(params.notesDirPath);
    final assetsDir = Directory(params.assetsDirPath);
    final tempSafetyDir = Directory(params.tempSafetyDirPath);

    if (params.mode == ImportMode.replaceAll) {
      await _backupService.executeReplaceAll(
        extractDir: extractDir,
        notesDir: notesDir,
        assetsDir: assetsDir,
        tempSafetyDir: tempSafetyDir,
      );
    } else {
      await _backupService.executeMerge(
        extractDir: extractDir,
        notesDir: notesDir,
        assetsDir: assetsDir,
      );
    }

    // Pasca impor: rebuild indeks, daftar ulang nada, reschedule pengingat.
    if (_indexManager != null) {
      await _indexManager!.rebuildIndex(notesDir);
    }
    if (_tonesDataSource != null) {
      await _tonesDataSource!.reRegisterAllTones();
    }
    if (_reminderSyncService != null) {
      await _reminderSyncService!.reconcileAllReminders(
        forceRescheduleAll: true,
      );
    }
  }
}
