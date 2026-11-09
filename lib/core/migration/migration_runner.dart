import 'dart:convert';
import 'dart:io';

import '../utils/atomic_file_writer.dart';

class NewerSchemaVersionException implements Exception {
  final int fileVersion;
  final int supportedVersion;

  NewerSchemaVersionException(this.fileVersion, this.supportedVersion);

  @override
  String toString() =>
      'NewerSchemaVersionException: File schemaVersion $fileVersion is newer than supported $supportedVersion (read-only)';
}

class MigrationFailedException implements Exception {
  final String message;
  final Object? cause;

  MigrationFailedException(this.message, [this.cause]);

  @override
  String toString() => 'MigrationFailedException: $message ${cause != null ? '($cause)' : ''}';
}

class MigrationRunResult {
  final int migratedCount;
  final bool hasNewerSchemaVersion;
  final int? maxDetectedVersion;

  const MigrationRunResult({
    required this.migratedCount,
    required this.hasNewerSchemaVersion,
    this.maxDetectedVersion,
  });
}

typedef MigrationStep = Map<String, dynamic> Function(Map<String, dynamic> json);

class MigrationRunner {
  static const int currentSchemaVersion = 1;

  final Map<int, MigrationStep> _migrations;
  final int targetVersion;

  MigrationRunner({
    Map<int, MigrationStep>? migrations,
    this.targetVersion = currentSchemaVersion,
  }) : _migrations = migrations ?? {};

  /// Menjalankan migrasi pada satu map JSON secara murni (in-memory)
  Map<String, dynamic> migrateJson(Map<String, dynamic> inputJson) {
    final fileVersion = (inputJson['schemaVersion'] as num?)?.toInt() ?? 1;

    if (fileVersion > targetVersion) {
      throw NewerSchemaVersionException(fileVersion, targetVersion);
    }

    if (fileVersion == targetVersion) {
      return Map<String, dynamic>.from(inputJson);
    }

    var current = Map<String, dynamic>.from(inputJson);
    var v = fileVersion;

    while (v < targetVersion) {
      final step = _migrations[v];
      if (step == null) {
        throw MigrationFailedException('No migration registered for v$v -> v${v + 1}');
      }
      try {
        current = step(current);
        v++;
        current['schemaVersion'] = v;
      } catch (e) {
        throw MigrationFailedException('Error migrating from v$v to v${v + 1}', e);
      }
    }

    return current;
  }

  /// Menjalankan migrasi terhadap `notes_data/` dan `notes_assets/tones.json` saat startup.
  Future<MigrationRunResult> migrateStartup({
    required Directory notesDir,
    required File tonesFile,
  }) async {
    final files = <File>[];
    if (await notesDir.exists()) {
      files.addAll(await _collectJsonFiles(notesDir));
    }
    if (await tonesFile.exists()) {
      files.add(tonesFile);
    }
    return _migrateFiles(files);
  }

  /// Menjalankan migrasi seluruh file JSON di direktori dengan proteksi backup *.bak dan rollback.
  /// Idempoten: bila seluruh file sudah versi terbaru, tidak ada tulis ulang dan tidak ada *.bak tersisa.
  Future<void> migrateDirectory(Directory rootDir) async {
    if (!await rootDir.exists()) return;
    final files = await _collectJsonFiles(rootDir);
    await _migrateFiles(files);
  }

  Future<List<File>> _collectJsonFiles(Directory dir) async {
    final jsonFiles = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith('.json') &&
          !entity.path.endsWith('.bak') &&
          !entity.path.endsWith('.tmp')) {
        jsonFiles.add(entity);
      }
    }
    return jsonFiles;
  }

  Future<MigrationRunResult> _migrateFiles(List<File> jsonFiles) async {
    if (jsonFiles.isEmpty) {
      return const MigrationRunResult(
        migratedCount: 0,
        hasNewerSchemaVersion: false,
      );
    }

    // Pass 1 (Baca-saja): inspeksi semua schemaVersion terlebih dahulu tanpa membuat *.bak.
    final toMigrate = <_PendingMigration>[];
    bool hasNewer = false;
    int? maxNewerVersion;

    for (final file in jsonFiles) {
      if (!await file.exists()) continue;
      final Map<String, dynamic> decoded;
      try {
        final content = await file.readAsString(encoding: utf8);
        final parsed = json.decode(content);
        if (parsed is! Map<String, dynamic>) {
          throw FormatException('Root JSON bukan objek pada ${file.path}');
        }
        decoded = parsed;
      } catch (e) {
        throw MigrationFailedException(
          'Gagal membaca file JSON saat inspeksi migrasi: ${file.path}',
          e,
        );
      }

      final version = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
      if (version > targetVersion) {
        hasNewer = true;
        if (maxNewerVersion == null || version > maxNewerVersion) {
          maxNewerVersion = version;
        }
        continue;
      }

      if (version < targetVersion) {
        toMigrate.add(_PendingMigration(file: file, decoded: decoded));
      }
    }

    // Idempoten: bila semua sudah versi terbaru atau ada schemaVersion lebih baru, tidak ada tulis ulang dan tidak ada *.bak dibuat.
    if (toMigrate.isEmpty || hasNewer) {
      return MigrationRunResult(
        migratedCount: 0,
        hasNewerSchemaVersion: hasNewer,
        maxDetectedVersion: maxNewerVersion,
      );
    }

    // Pass 2: buat backup *.bak HANYA untuk file yang perlu dimigrasi.
    final backups = <File, File>{};
    try {
      for (final item in toMigrate) {
        final bakFile = File('${item.file.path}.bak');
        await item.file.copy(bakFile.path);
        backups[item.file] = bakFile;
      }

      // Pass 3: jalankan migrasi dan tulis atomik.
      for (final item in toMigrate) {
        final migrated = migrateJson(item.decoded);
        await AtomicFileWriter.writeJson(item.file, migrated);
      }

      // Semua berhasil: hapus semua *.bak.
      for (final bak in backups.values) {
        if (await bak.exists()) {
          await bak.delete();
        }
      }

      return MigrationRunResult(
        migratedCount: toMigrate.length,
        hasNewerSchemaVersion: hasNewer,
        maxDetectedVersion: maxNewerVersion,
      );
    } catch (e) {
      // Rollback seluruh file dari *.bak tanpa mengubah data asli.
      for (final entry in backups.entries) {
        final original = entry.key;
        final bak = entry.value;
        if (await bak.exists()) {
          try {
            if (await original.exists()) {
              await original.delete();
            }
            await bak.rename(original.path);
          } catch (_) {
            await bak.copy(original.path);
            if (await bak.exists()) {
              await bak.delete();
            }
          }
        }
      }
      if (e is MigrationFailedException) {
        rethrow;
      }
      throw MigrationFailedException('Directory migration failed and rolled back', e);
    }
  }
}

class _PendingMigration {
  final File file;
  final Map<String, dynamic> decoded;

  const _PendingMigration({
    required this.file,
    required this.decoded,
  });
}
