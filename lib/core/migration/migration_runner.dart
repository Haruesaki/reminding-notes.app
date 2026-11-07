import 'dart:convert';
import 'dart:io';

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
    final fileVersion = inputJson['schemaVersion'] as int? ?? 1;

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

  /// Menjalankan migrasi seluruh file JSON di direktori dengan proteksi backup *.bak dan rollback
  Future<void> migrateDirectory(Directory rootDir) async {
    if (!await rootDir.exists()) return;

    final jsonFiles = <File>[];
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json') && !entity.path.endsWith('.bak')) {
        jsonFiles.add(entity);
      }
    }

    if (jsonFiles.isEmpty) return;

    // 1. Buat backup *.bak untuk semua file
    final backups = <File, File>{};
    for (final file in jsonFiles) {
      final bakFile = File('${file.path}.bak');
      await file.copy(bakFile.path);
      backups[file] = bakFile;
    }

    // 2. Jalankan migrasi pada tiap file
    try {
      for (final file in jsonFiles) {
        final content = await file.readAsString(encoding: utf8);
        final decoded = json.decode(content) as Map<String, dynamic>;
        final version = decoded['schemaVersion'] as int? ?? 1;

        if (version > targetVersion) {
          // Versi lebih baru: biarkan read-only, jangan sentuh
          continue;
        }

        if (version < targetVersion) {
          final migrated = migrateJson(decoded);
          final tmpFile = File('${file.path}.tmp');
          await tmpFile.writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(migrated)}\n',
            encoding: utf8,
            flush: true,
          );
          try {
            if (await file.exists()) {
              await file.delete();
            }
            await tmpFile.rename(file.path);
          } catch (_) {
            await tmpFile.copy(file.path);
            if (await tmpFile.exists()) {
              await tmpFile.delete();
            }
          }
        }
      }

      // 3. Jika SEMUA sukses, hapus file *.bak
      for (final bak in backups.values) {
        if (await bak.exists()) {
          await bak.delete();
        }
      }
    } catch (e) {
      // 4. Jika terjadi kegagalan: ROLLBACK seluruh file dari *.bak
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
      throw MigrationFailedException('Directory migration failed and rolled back', e);
    }
  }
}
