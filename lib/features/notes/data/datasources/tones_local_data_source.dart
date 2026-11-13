import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:reminding/core/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/migration/data_access_mode.dart';
import '../../../../core/migration/migration_runner.dart';
import '../../../explorer/data/models/task_models.dart';
import '../../../explorer/domain/entities/tone_ref.dart';
import '../../../../core/utils/atomic_file_writer.dart';
import '../../../../core/utils/app_logger.dart';
import '../services/media_store_service.dart';

class ToneFileSizeLimitException implements Exception {
  final int sizeInBytes;
  ToneFileSizeLimitException(this.sizeInBytes);

  @override
  String toString() =>
      'Ukuran file melebihi batas 10 MB (${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB)';
}

/// Ekstensi file nada tidak didukung.
class ToneFileFormatException implements Exception {
  final String extension;
  ToneFileFormatException(this.extension);

  @override
  String toString() =>
      'Ekstensi file nada "$extension" tidak didukung. Gunakan .mp3, .m4a, .ogg, atau .wav.';
}

class TonesLocalDataSource {
  final Directory assetsDir;
  final Directory? notesDir;
  final DataAccessMode? dataAccessMode;
  final MediaStoreService _mediaStoreService;
  final Uuid _uuid;

  TonesLocalDataSource({
    required this.assetsDir,
    this.notesDir,
    this.dataAccessMode,
    MediaStoreService? mediaStoreService,
    Uuid? uuid,
  })  : _mediaStoreService = mediaStoreService ?? MediaStoreService(),
        _uuid = uuid ?? const Uuid();

  void _ensureWritable() {
    if (dataAccessMode?.hasMigrationError == true) {
      throw StateError('Aplikasi dalam status gagal migrasi.');
    }
    dataAccessMode?.ensureWritable();
  }

  void _inspectSchemaVersion(Map<String, dynamic> map) {
    final version = (map['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > MigrationRunner.currentSchemaVersion) {
      dataAccessMode?.markReadOnly(detectedVersion: version);
    }
  }

  Directory get tonesDir => Directory(p.join(assetsDir.path, 'tones'));
  File get tonesMetaFile => File(p.join(assetsDir.path, 'tones.json'));

  /// Memastikan folder assets dan tones.json tersedia, serta pulihkan *.tmp yatim
  Future<void> init() async {
    if (dataAccessMode?.hasMigrationError == true ||
        dataAccessMode?.isReadOnly == true) {
      return;
    }
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    if (!await tonesDir.exists()) {
      await tonesDir.create(recursive: true);
    }
    await AtomicFileWriter.recoverTargetOrphans(tonesMetaFile);
    if (!await tonesMetaFile.exists()) {
      final initialData = {
        'schemaVersion': 1,
        'tones': <Map<String, dynamic>>[],
      };
      await _atomicWrite(tonesMetaFile, initialData);
    } else {
      try {
        final text = await tonesMetaFile.readAsString();
        final map = jsonDecode(text);
        if (map is Map<String, dynamic>) {
          _inspectSchemaVersion(map);
        }
      } catch (e, st) {
          AppLogger.error(e, st);
        }
    }
  }

  Future<void> _atomicWrite(File target, Map<String, dynamic> json) async {
    _ensureWritable();
    await AtomicFileWriter.writeJson(target, json, uuid: _uuid);
  }

  /// Membaca daftar nada dari tones.json
  Future<List<ToneRef>> getTones() async {
    if (!tonesMetaFile.existsSync()) {
      if (dataAccessMode?.isReadOnly == true ||
          dataAccessMode?.hasMigrationError == true) {
        return [];
      }
      await init();
      return [];
    }
    try {
      final text = await tonesMetaFile.readAsString();
      final map = jsonDecode(text) as Map<String, dynamic>;
      _inspectSchemaVersion(map);
      final list = map['tones'] as List<dynamic>? ?? [];
      return list
          .map((e) => ToneRefModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.error(e, st);
      return [];
    }
  }

  Future<ToneRef?> getToneById(String id) async {
    final list = await getTones();
    try {
      return list.firstWhere((t) => t.id == id);
    } catch (e, st) {
      AppLogger.error(e, st);
      return null;
    }
  }

  /// Menambahkan nada baru dari file yang dipilih pengguna
  Future<ToneRef> addTone({
    required File sourceFile,
    required String name,
    String? contentUri,
  }) async {
    _ensureWritable();
    await init();

    final size = await sourceFile.length();
    // Batas 10 MB (10 * 1024 * 1024 bytes) — sesuai PRD 7.6.
    if (size > 10 * 1024 * 1024) {
      throw ToneFileSizeLimitException(size);
    }

    final ext = p.extension(sourceFile.path).toLowerCase();
    final validExtensions = ['.mp3', '.m4a', '.ogg', '.wav'];
    if (!validExtensions.contains(ext)) {
      throw ToneFileFormatException(ext);
    }

    final toneId = _uuid.v4();
    final targetFileName = '$toneId$ext';
    final targetFile = File(p.join(tonesDir.path, targetFileName));

    await sourceFile.copy(targetFile.path);

    final resolvedTitle = name.trim().isEmpty ? p.basenameWithoutExtension(sourceFile.path) : name.trim();
    String? resolvedUri = contentUri;
    resolvedUri ??= await _mediaStoreService.registerToneToMediaStore(
      filePath: targetFile.path,
      title: resolvedTitle,
    );

    final tone = ToneRef(
      id: toneId,
      name: resolvedTitle,
      relativePath: p.join('tones', targetFileName),
      contentUri: resolvedUri,
    );

    final currentTones = await getTones();
    final updated = List<ToneRef>.from(currentTones)..add(tone);

    await _saveTonesMeta(updated);
    return tone;
  }

  /// Menghapus nada dari disk dan metadata
  Future<void> deleteTone(String toneId) async {
    _ensureWritable();
    final currentTones = await getTones();
    final index = currentTones.indexWhere((t) => t.id == toneId);
    if (index == -1) return;

    final targetTone = currentTones[index];
    if (targetTone.contentUri != null) {
      await _mediaStoreService.deleteToneFromMediaStore(targetTone.contentUri!);
    }
    await _mediaStoreService.deleteNotificationChannel('reminder_${targetTone.id}');

    final file = File(p.join(assetsDir.path, targetTone.relativePath));
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (e, st) {
          AppLogger.error(e, st);
        }
    }

    final updated = List<ToneRef>.from(currentTones)..removeAt(index);
    await _saveTonesMeta(updated);

    // Reset task yang memakai nada ini
    if (notesDir != null && notesDir!.existsSync()) {
      await resetToneInTasks(toneId);
    }
  }

  /// Menghitung jumlah task yang memakai nada ini
  Future<int> countAffectedTasks(String toneId) async {
    if (notesDir == null || !notesDir!.existsSync()) return 0;
    int count = 0;
    final jsonFiles = notesDir!
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !p.basename(f.path).startsWith('_'));

    for (final file in jsonFiles) {
      try {
        final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        if (content['type'] == 'list') {
          final tasks = content['tasks'] as List<dynamic>? ?? [];
          for (final t in tasks) {
            if (t is Map<String, dynamic>) {
              final dl = t['deadline'] as Map<String, dynamic>?;
              final al = t['alarm'] as Map<String, dynamic>?;
              if (dl != null && dl['notificationToneId'] == toneId) {
                count++;
              } else if (al != null && al['toneId'] == toneId) {
                count++;
              }
            }
          }
        }
      } catch (e, st) {
          AppLogger.error(e, st);
        }
    }
    return count;
  }

  /// Mengembalikan task yang memakai nada ke Bawaan Sistem (null)
  Future<void> resetToneInTasks(String toneId) async {
    _ensureWritable();
    if (notesDir == null || !notesDir!.existsSync()) return;
    final jsonFiles = notesDir!
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !p.basename(f.path).startsWith('_'));

    for (final file in jsonFiles) {
      try {
        final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        if (content['type'] == 'list') {
          bool changed = false;
          final tasks = content['tasks'] as List<dynamic>? ?? [];
          for (final t in tasks) {
            if (t is Map<String, dynamic>) {
              final dl = t['deadline'] as Map<String, dynamic>?;
              final al = t['alarm'] as Map<String, dynamic>?;
              if (dl != null && dl['notificationToneId'] == toneId) {
                dl['notificationToneId'] = null;
                changed = true;
              }
              if (al != null && al['toneId'] == toneId) {
                al['toneId'] = null;
                changed = true;
              }
            }
          }
          if (changed) {
            await _atomicWrite(file, content);
          }
        }
      } catch (e, st) {
          AppLogger.error(e, st);
        }
    }
  }

  Future<void> _saveTonesMeta(List<ToneRef> tones) async {
    final models = tones.map((t) => ToneRefModel(
          id: t.id,
          name: t.name,
          relativePath: t.relativePath,
          contentUri: t.contentUri,
        ));
    final data = {
      'schemaVersion': 1,
      'tones': models.map((m) => m.toJson()).toList(),
    };
    await _atomicWrite(tonesMetaFile, data);
  }

  /// Mendaftarkan ulang semua nada ke sistem MediaStore setelah import (PRD 7.11)
  Future<void> reRegisterAllTones() async {
    _ensureWritable();
    final tones = await getTones();
    final updatedTones = <ToneRef>[];
    for (final tone in tones) {
      final file = File(p.join(assetsDir.path, tone.relativePath));
      if (file.existsSync()) {
        try {
          final uri = await _mediaStoreService.registerToneToMediaStore(
            filePath: file.path,
            title: tone.name,
          );
          updatedTones.add(ToneRef(
            id: tone.id,
            name: tone.name,
            relativePath: tone.relativePath,
            contentUri: uri ?? tone.contentUri,
          ));
        } catch (e, st) {
          AppLogger.error(e, st);
          updatedTones.add(tone);
        }
      } else {
        updatedTones.add(tone);
      }
    }
    await _saveTonesMeta(updatedTones);
  }
}
