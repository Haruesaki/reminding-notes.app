import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/features/backup/domain/models/backup_inspection_result.dart';
import 'package:reminding/features/backup/domain/models/backup_manifest.dart';
import 'package:reminding/features/backup/domain/repositories/backup_repository.dart';
import 'package:reminding/features/backup/domain/usecases/backup_usecases.dart';
import 'package:reminding/features/backup/presentation/bloc/backup_bloc.dart';

class FakeBackupRepository implements BackupRepository {
  Uint8List? exportBytes;
  BackupInspectionResult? inspectionResult;
  bool shouldThrowExport = false;
  bool shouldThrowInspect = false;
  bool shouldThrowImport = false;
  Exception? exportError;
  Exception? inspectError;
  Exception? importError;
  int importCallCount = 0;
  ImportMode? lastImportMode;

  @override
  Future<Uint8List> exportBackup(ExportBackupParams params) async {
    if (shouldThrowExport) throw exportError!;
    return exportBytes ?? Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<BackupInspectionResult> inspectBackup(InspectBackupParams params) async {
    if (shouldThrowInspect) throw inspectError!;
    return inspectionResult ??
        BackupInspectionResult(
          manifest: BackupManifest(
            app: 'reminding',
            backupFormat: 1,
            schemaVersion: 1,
            appVersion: '1.0.0',
            createdAt: DateTime(2026, 11, 13),
            counts: {'notes': 2, 'folders': 1, 'tones': 0, 'totalFiles': 3},
            files: [],
          ),
          extractDirPath: '/tmp/extract',
        );
  }

  @override
  Future<void> importBackup(ImportBackupParams params) async {
    importCallCount++;
    lastImportMode = params.mode;
    if (shouldThrowImport) throw importError!;
  }
}

void main() {
  group('BackupBloc', () {
    late FakeBackupRepository fakeRepo;
    late BackupBloc bloc;

    setUp(() {
      fakeRepo = FakeBackupRepository();
      bloc = BackupBloc(
        exportBackup: ExportBackup(fakeRepo),
        inspectBackup: InspectBackup(fakeRepo),
        importBackup: ImportBackup(fakeRepo),
        notesDirPath: '/notes',
        assetsDirPath: '/assets',
        tempSafetyDirPath: '/safety',
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('eksport sukses emits busy then success with bytes', () async {
      fakeRepo.exportBytes = Uint8List.fromList([104, 101, 108, 108, 111]);

      bloc.add(const BackupExportRequested());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.success);
      expect(bloc.state.operation, BackupOperation.export);
      expect(bloc.lastExportBytes, Uint8List.fromList([104, 101, 108, 108, 111]));
    });

    test('eksport gagal emits error', () async {
      fakeRepo.shouldThrowExport = true;
      fakeRepo.exportError = Exception('disk full');

      bloc.add(const BackupExportRequested());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('disk full'));
    });

    test('inspeksi sukses emits success with inspection result', () async {
      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.success);
      expect(bloc.state.operation, BackupOperation.import);
      expect(bloc.state.inspection, isNotNull);
      expect(bloc.state.inspection!.manifest.counts['notes'], 2);
    });

    test('inspeksi gagal path berbahaya emits error spesifik', () async {
      fakeRepo.shouldThrowInspect = true;
      fakeRepo.inspectError = Exception(
        'DangerousPathException: Terdeteksi path berbahaya dalam file backup: ../evil',
      );

      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('path berbahaya'));
    });

    test('inspeksi gagal versi lebih baru emits error spesifik', () async {
      fakeRepo.shouldThrowInspect = true;
      fakeRepo.inspectError = Exception(
        'NewerSchemaVersionException: file 2, supported 1',
      );

      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('lebih baru'));
    });

    test('inspeksi gagal korup emits error spesifik', () async {
      fakeRepo.shouldThrowInspect = true;
      fakeRepo.inspectError = Exception(
        'CorruptedBackupException: file rusak',
      );

      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('rusak'));
    });

    test('inspeksi gagal invalid emits error spesifik', () async {
      fakeRepo.shouldThrowInspect = true;
      fakeRepo.inspectError = Exception('InvalidBackupException: tidak valid');

      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('tidak valid'));
    });

    test('impor merge sukses emits success', () async {
      // First inspect to set pending inspection
      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Then select merge mode
      bloc.add(const BackupImportModeSelected(ImportMode.merge));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.success);
      expect(bloc.state.operation, BackupOperation.import);
      expect(fakeRepo.importCallCount, 1);
      expect(fakeRepo.lastImportMode, ImportMode.merge);
    });

    test('impor replaceAll sukses emits success', () async {
      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const BackupImportModeSelected(ImportMode.replaceAll));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.success);
      expect(fakeRepo.lastImportMode, ImportMode.replaceAll);
    });

    test('impor gagal emits error', () async {
      fakeRepo.shouldThrowImport = true;
      fakeRepo.importError = Exception('gagal impor');

      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const BackupImportModeSelected(ImportMode.merge));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.error);
      expect(bloc.state.error, contains('gagal impor'));
    });

    test('impor dibatalkan reset state', () async {
      bloc.add(const BackupImportPickRequested(
        zipBytes: [1, 2, 3],
        tempExtractDirPath: '/tmp/extract',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const BackupImportCancelled());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.initial);
      expect(bloc.state.inspection, isNull);
    });

    test('reset kembali ke initial', () async {
      bloc.add(const BackupExportRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const BackupReset());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, BackupStatus.initial);
    });
  });
}
