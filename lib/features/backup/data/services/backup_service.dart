import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/migration/migration_runner.dart';
import '../../../../core/utils/name_sanitizer.dart';
import '../../../explorer/data/models/list_file_model.dart';
import '../../../explorer/domain/entities/list_file.dart';
import '../../../notes/data/datasources/tones_local_data_source.dart';
import '../../../notes/data/services/notification_service.dart';
import '../../domain/models/backup_exceptions.dart';
import '../../domain/models/backup_manifest.dart';

class BackupParams {
  final String notesDirPath;
  final String assetsDirPath;
  final String appName;
  final String appVersion;
  final int schemaVersion;
  final int backupFormat;

  const BackupParams({
    required this.notesDirPath,
    required this.assetsDirPath,
    required this.appName,
    required this.appVersion,
    required this.schemaVersion,
    required this.backupFormat,
  });
}

class BackupInspectionResult {
  final BackupManifest manifest;
  final Directory extractDir;

  const BackupInspectionResult({
    required this.manifest,
    required this.extractDir,
  });
}

class BackupService {
  /// Top-level/static entry point yang dieksekusi di Isolate untuk membuat ZIP backup
  static Uint8List createBackupBytes(BackupParams params) {
    final archive = Archive();
    final manifestFiles = <BackupFileEntry>[];
    int notesCount = 0;
    int foldersCount = 0;
    int tonesCount = 0;

    final notesDir = Directory(params.notesDirPath);
    if (notesDir.existsSync()) {
      for (final entity in notesDir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.endsWith('.tmp') || fileName.endsWith('.bak')) {
            continue;
          }
          final relPath = p.relative(entity.path, from: notesDir.path).replaceAll(r'\', '/');
          final zipEntryPath = 'data/$relPath';
          final bytes = entity.readAsBytesSync();
          final hash = sha256.convert(bytes).toString();

          archive.addFile(ArchiveFile(zipEntryPath, bytes.length, bytes));
          manifestFiles.add(BackupFileEntry(path: zipEntryPath, sha256: hash));

          if (fileName == '_folder.json') {
            if (relPath != '_folder.json') {
              foldersCount++;
            }
          } else if (fileName.endsWith('.json')) {
            notesCount++;
          }
        }
      }
    }

    final assetsDir = Directory(params.assetsDirPath);
    if (assetsDir.existsSync()) {
      final tonesMeta = File(p.join(assetsDir.path, 'tones.json'));
      if (tonesMeta.existsSync()) {
        final bytes = tonesMeta.readAsBytesSync();
        final hash = sha256.convert(bytes).toString();
        const zipEntryPath = 'assets/tones.json';
        archive.addFile(ArchiveFile(zipEntryPath, bytes.length, bytes));
        manifestFiles.add(const BackupFileEntry(path: zipEntryPath, sha256: '').copyWith(sha256: hash));
      }

      final tonesDir = Directory(p.join(assetsDir.path, 'tones'));
      if (tonesDir.existsSync()) {
        for (final entity in tonesDir.listSync(recursive: false, followLinks: false)) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            if (fileName.endsWith('.tmp') || fileName.endsWith('.bak')) {
              continue;
            }
            final zipEntryPath = 'assets/tones/$fileName';
            final bytes = entity.readAsBytesSync();
            final hash = sha256.convert(bytes).toString();

            archive.addFile(ArchiveFile(zipEntryPath, bytes.length, bytes));
            manifestFiles.add(BackupFileEntry(path: zipEntryPath, sha256: hash));
            tonesCount++;
          }
        }
      }
    }

    final manifest = BackupManifest(
      app: params.appName,
      backupFormat: params.backupFormat,
      schemaVersion: params.schemaVersion,
      appVersion: params.appVersion,
      createdAt: DateTime.now(),
      counts: {
        'notes': notesCount,
        'folders': foldersCount,
        'tones': tonesCount,
        'totalFiles': manifestFiles.length,
      },
      files: manifestFiles,
    );

    final manifestJsonString = '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n';
    final manifestBytes = utf8.encode(manifestJsonString);
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Menjalankan pembuatan backup di Isolate dengan fallback bila platform tidak mendukung
  Future<Uint8List> createBackup({
    required Directory notesDir,
    required Directory assetsDir,
  }) async {
    final params = BackupParams(
      notesDirPath: notesDir.path,
      assetsDirPath: assetsDir.path,
      appName: AppConstants.appName,
      appVersion: AppConstants.appVersion,
      schemaVersion: AppConstants.schemaVersion,
      backupFormat: AppConstants.backupFormat,
    );

    return compute(createBackupBytes, params);
  }

  /// Mengekstrak file ZIP backup ke tempExtractDir dan memvalidasi seluruh syarat integritas (PRD 7.11)
  Future<BackupInspectionResult> inspectBackup({
    required List<int> zipBytes,
    required Directory tempExtractDir,
  }) async {
    if (tempExtractDir.existsSync()) {
      tempExtractDir.deleteSync(recursive: true);
    }
    tempExtractDir.createSync(recursive: true);

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw InvalidBackupException('File ZIP rusak atau bukan format ZIP yang valid.');
    }

    // 1. Validasi Zip Slip (Path Berbahaya) & Ekstraksi
    for (final file in archive) {
      final name = file.name;
      // Periksa path traversal
      if (name.contains('..') ||
          name.startsWith('/') ||
          name.startsWith(r'\') ||
          (name.length > 2 && name[1] == ':')) {
        throw DangerousPathException(name);
      }

      final destPath = p.normalize(p.join(tempExtractDir.path, name));
      if (!p.isWithin(tempExtractDir.path, destPath) && destPath != tempExtractDir.path) {
        throw DangerousPathException(name);
      }

      if (file.isFile) {
        final outFile = File(destPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(destPath).createSync(recursive: true);
      }
    }

    // 2. Validasi manifest.json
    final manifestFile = File(p.join(tempExtractDir.path, 'manifest.json'));
    if (!manifestFile.existsSync()) {
      throw InvalidBackupException('manifest.json tidak ditemukan dalam file backup.');
    }

    final Map<String, dynamic> manifestMap;
    try {
      final text = manifestFile.readAsStringSync(encoding: utf8);
      manifestMap = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw InvalidBackupException('manifest.json rusak dan tidak dapat di-parse.');
    }

    final fileSchemaVersion = manifestMap['schemaVersion'] as int? ?? 1;
    if (fileSchemaVersion > AppConstants.schemaVersion) {
      throw NewerSchemaVersionException(fileSchemaVersion, AppConstants.schemaVersion);
    }

    final manifest = BackupManifest.fromJson(manifestMap);

    // 3. Validasi Checksum & Parse JSON
    final corruptedFiles = <String>[];
    for (final fileEntry in manifest.files) {
      final fileOnDisk = File(p.join(tempExtractDir.path, fileEntry.path));
      if (!fileOnDisk.existsSync()) {
        corruptedFiles.add(fileEntry.path);
        continue;
      }

      final bytes = fileOnDisk.readAsBytesSync();
      final calculatedHash = sha256.convert(bytes).toString();
      if (calculatedHash != fileEntry.sha256) {
        corruptedFiles.add(fileEntry.path);
        continue;
      }

      if (fileEntry.path.endsWith('.json')) {
        try {
          final content = utf8.decode(bytes);
          jsonDecode(content);
        } catch (_) {
          corruptedFiles.add(fileEntry.path);
        }
      }
    }

    if (corruptedFiles.isNotEmpty) {
      throw CorruptedBackupException(corruptedFiles);
    }

    // 4. Migrasi otomatis jika versi lama (PRD 6.7)
    if (manifest.schemaVersion < AppConstants.schemaVersion) {
      final dataDir = Directory(p.join(tempExtractDir.path, 'data'));
      if (dataDir.existsSync()) {
        final runner = MigrationRunner(targetVersion: AppConstants.schemaVersion);
        await runner.migrateDirectory(dataDir);
      }
    }

    return BackupInspectionResult(
      manifest: manifest,
      extractDir: tempExtractDir,
    );
  }

  /// Eksekusi Impor Mode "Ganti Semua" dengan backup pengaman internal dan rollback (PRD 7.11)
  Future<void> executeReplaceAll({
    required Directory extractDir,
    required Directory notesDir,
    required Directory assetsDir,
    required Directory tempSafetyDir,
  }) async {
    // 1. Buat safety backup
    if (tempSafetyDir.existsSync()) {
      tempSafetyDir.deleteSync(recursive: true);
    }
    tempSafetyDir.createSync(recursive: true);

    final safetyNotesDir = Directory(p.join(tempSafetyDir.path, 'notes_data'));
    final safetyAssetsDir = Directory(p.join(tempSafetyDir.path, 'notes_assets'));

    if (notesDir.existsSync()) {
      _copyDirectorySync(notesDir, safetyNotesDir);
    }
    if (assetsDir.existsSync()) {
      _copyDirectorySync(assetsDir, safetyAssetsDir);
    }

    try {
      // 2. Kosongkan direktori saat ini
      if (notesDir.existsSync()) {
        notesDir.deleteSync(recursive: true);
      }
      notesDir.createSync(recursive: true);

      if (assetsDir.existsSync()) {
        assetsDir.deleteSync(recursive: true);
      }
      assetsDir.createSync(recursive: true);

      // 3. Salin data dari hasil ekstraksi
      final sourceDataDir = Directory(p.join(extractDir.path, 'data'));
      if (sourceDataDir.existsSync()) {
        _copyDirectorySync(sourceDataDir, notesDir);
      }

      final sourceAssetsDir = Directory(p.join(extractDir.path, 'assets'));
      if (sourceAssetsDir.existsSync()) {
        _copyDirectorySync(sourceAssetsDir, assetsDir);
      }
    } catch (e) {
      // 4. Rollback dari safety backup jika terjadi kegagalan
      if (notesDir.existsSync()) {
        try {
          notesDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (safetyNotesDir.existsSync()) {
        notesDir.createSync(recursive: true);
        _copyDirectorySync(safetyNotesDir, notesDir);
      }

      if (assetsDir.existsSync()) {
        try {
          assetsDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (safetyAssetsDir.existsSync()) {
        assetsDir.createSync(recursive: true);
        _copyDirectorySync(safetyAssetsDir, assetsDir);
      }

      rethrow;
    } finally {
      // Bersihkan safety backup setelah selesai
      if (tempSafetyDir.existsSync()) {
        try {
          tempSafetyDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Eksekusi Impor Mode "Gabungkan" (Merge) (PRD 7.11)
  /// Bentrok nama menghasilkan salinan " (Impor)", ID baru dialokasikan jika perlu
  Future<void> executeMerge({
    required Directory extractDir,
    required Directory notesDir,
    required Directory assetsDir,
  }) async {
    final sourceDataDir = Directory(p.join(extractDir.path, 'data'));
    if (sourceDataDir.existsSync()) {
      if (!notesDir.existsSync()) {
        notesDir.createSync(recursive: true);
      }
      _mergeFolderRecursive(sourceDataDir, notesDir);
    }

    final sourceAssetsDir = Directory(p.join(extractDir.path, 'assets'));
    if (sourceAssetsDir.existsSync()) {
      if (!assetsDir.existsSync()) {
        assetsDir.createSync(recursive: true);
      }

      // Merge tones files
      final sourceTonesDir = Directory(p.join(sourceAssetsDir.path, 'tones'));
      final targetTonesDir = Directory(p.join(assetsDir.path, 'tones'));
      if (sourceTonesDir.existsSync()) {
        if (!targetTonesDir.existsSync()) {
          targetTonesDir.createSync(recursive: true);
        }
        for (final entity in sourceTonesDir.listSync(recursive: false, followLinks: false)) {
          if (entity is File) {
            final targetFile = File(p.join(targetTonesDir.path, p.basename(entity.path)));
            if (!targetFile.existsSync()) {
              entity.copySync(targetFile.path);
            }
          }
        }
      }

      // Merge tones.json
      final sourceTonesMeta = File(p.join(sourceAssetsDir.path, 'tones.json'));
      final targetTonesMeta = File(p.join(assetsDir.path, 'tones.json'));
      if (sourceTonesMeta.existsSync()) {
        try {
          final srcJson = jsonDecode(sourceTonesMeta.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
          final srcList = srcJson['tones'] as List<dynamic>? ?? [];

          final Map<String, dynamic> tgtJson;
          if (targetTonesMeta.existsSync()) {
            tgtJson = jsonDecode(targetTonesMeta.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
          } else {
            tgtJson = {'schemaVersion': 1, 'tones': <Map<String, dynamic>>[]};
          }
          final tgtList = tgtJson['tones'] as List<dynamic>? ?? [];
          final existingIds = tgtList
              .whereType<Map<String, dynamic>>()
              .map((e) => e['id'] as String?)
              .whereType<String>()
              .toSet();

          for (final tone in srcList) {
            if (tone is Map<String, dynamic>) {
              final id = tone['id'] as String?;
              if (id != null && !existingIds.contains(id)) {
                tgtList.add(tone);
                existingIds.add(id);
              }
            }
          }
          tgtJson['tones'] = tgtList;
          targetTonesMeta.writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(tgtJson)}\n',
            encoding: utf8,
            flush: true,
          );
        } catch (_) {}
      }
    }
  }

  void _mergeFolderRecursive(Directory sourceDir, Directory targetDir) {
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // 1. Ambil order yang ada di target _folder.json
    final targetMetaFile = File(p.join(targetDir.path, '_folder.json'));
    Map<String, dynamic> targetMeta;
    if (targetMetaFile.existsSync()) {
      try {
        targetMeta = jsonDecode(targetMetaFile.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
      } catch (_) {
        targetMeta = {'order': <String>[]};
      }
    } else {
      targetMeta = {'order': <String>[]};
    }
    final targetOrder = (targetMeta['order'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    // 2. Kumpulkan existing names di target
    final existingEntries = targetDir.listSync(recursive: false, followLinks: false);
    final existingNames = existingEntries.map((e) => p.basename(e.path)).toSet();

    // Kumpulkan existing note IDs di seluruh notes data untuk mencegah duplikasi ID
    final existingIds = <String>{};
    for (final e in existingEntries) {
      if (e is File && e.path.endsWith('.json') && !p.basename(e.path).startsWith('_')) {
        try {
          final content = jsonDecode(e.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
          if (content['id'] != null) {
            existingIds.add(content['id'] as String);
          }
        } catch (_) {}
      } else if (e is Directory) {
        final subMeta = File(p.join(e.path, '_folder.json'));
        if (subMeta.existsSync()) {
          try {
            final content = jsonDecode(subMeta.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
            if (content['id'] != null) {
              existingIds.add(content['id'] as String);
            }
          } catch (_) {}
        }
      }
    }

    const uuid = Uuid();

    // 3. Iterasi setiap entitas di sourceDir
    final sourceEntries = sourceDir.listSync(recursive: false, followLinks: false);
    for (final entity in sourceEntries) {
      final name = p.basename(entity.path);
      if (name == '_folder.json' || name.endsWith('.tmp') || name.endsWith('.bak')) {
        continue;
      }

      if (entity is Directory) {
        final targetSubDir = Directory(p.join(targetDir.path, name));
        _mergeFolderRecursive(entity, targetSubDir);

        // Ambil folder id
        final subMeta = File(p.join(targetSubDir.path, '_folder.json'));
        if (subMeta.existsSync()) {
          try {
            final content = jsonDecode(subMeta.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
            final folderId = content['id'] as String?;
            if (folderId != null && !targetOrder.contains(folderId)) {
              targetOrder.add(folderId);
            }
          } catch (_) {}
        }
      } else if (entity is File && entity.path.endsWith('.json')) {
        try {
          final jsonMap = jsonDecode(entity.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
          var fileId = jsonMap['id'] as String? ?? uuid.v4();
          var title = jsonMap['title'] as String? ?? p.basenameWithoutExtension(name);

          // Cek bentrok nama
          final String finalFileName;
          if (existingNames.map((e) => e.toLowerCase()).contains(name.toLowerCase())) {
            final baseName = p.basenameWithoutExtension(name);
            final resolvedName = NameSanitizer.resolveImportCollision(
              baseName,
              existingNames,
              extension: '.json',
            );
            finalFileName = resolvedName;
            title = p.basenameWithoutExtension(resolvedName);
            fileId = uuid.v4(); // Generate new ID on collision
          } else {
            finalFileName = name;
            if (existingIds.contains(fileId)) {
              fileId = uuid.v4();
            }
          }

          jsonMap['id'] = fileId;
          jsonMap['title'] = title;

          final destFile = File(p.join(targetDir.path, finalFileName));
          destFile.writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(jsonMap)}\n',
            encoding: utf8,
            flush: true,
          );

          existingNames.add(finalFileName);
          existingIds.add(fileId);
          if (!targetOrder.contains(fileId)) {
            targetOrder.add(fileId);
          }
        } catch (_) {}
      }
    }

    // 4. Simpan order baru di _folder.json
    targetMeta['order'] = targetOrder;
    targetMetaFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(targetMeta)}\n',
      encoding: utf8,
      flush: true,
    );
  }

  static void _copyDirectorySync(Directory src, Directory dst) {
    if (!dst.existsSync()) {
      dst.createSync(recursive: true);
    }
    for (final entity in src.listSync(recursive: false, followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        _copyDirectorySync(entity, Directory(p.join(dst.path, name)));
      } else if (entity is File) {
        entity.copySync(p.join(dst.path, name));
      }
    }
  }

  /// Menjadwalkan ulang semua notifikasi deadline setelah proses impor (PRD 7.11)
  static Future<void> rescheduleAllReminders({
    required Directory notesDir,
    required TonesLocalDataSource tonesDataSource,
    required NotificationService notificationService,
  }) async {
    final listFiles = <ListFile>[];
    if (notesDir.existsSync()) {
      for (final entity in notesDir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.json') && !p.basename(entity.path).startsWith('_')) {
          try {
            final content = jsonDecode(entity.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
            if (content['type'] == 'list') {
              final relPath = p.relative(entity.path, from: notesDir.path).replaceAll(r'\', '/');
              listFiles.add(ListFileModel.fromJson(content, relativePath: relPath));
            }
          } catch (_) {}
        }
      }
    }

    final tones = await tonesDataSource.getTones();
    final tonesMap = {for (final t in tones) t.id: t};
    await notificationService.reconcileAllReminders(
      listFiles: listFiles,
      tonesMap: tonesMap,
    );
  }
}

extension BackupFileEntryExt on BackupFileEntry {
  BackupFileEntry copyWith({String? path, String? sha256}) {
    return BackupFileEntry(
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
    );
  }
}
