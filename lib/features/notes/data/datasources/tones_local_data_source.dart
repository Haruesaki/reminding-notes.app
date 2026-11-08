import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../explorer/data/models/task_models.dart';
import '../../../explorer/domain/entities/tone_ref.dart';
import '../../../../core/utils/atomic_file_writer.dart';
import '../services/media_store_service.dart';

class ToneFileSizeLimitException implements Exception {
  final int sizeInBytes;
  ToneFileSizeLimitException(this.sizeInBytes);

  @override
  String toString() =>
      'Ukuran file melebihi batas 10 MB (${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB)';
}

class TonesLocalDataSource {
  final Directory assetsDir;
  final Directory? notesDir;
  final MediaStoreService _mediaStoreService;
  final Uuid _uuid;

  TonesLocalDataSource({
    required this.assetsDir,
    this.notesDir,
    MediaStoreService? mediaStoreService,
    Uuid? uuid,
  })  : _mediaStoreService = mediaStoreService ?? MediaStoreService(),
        _uuid = uuid ?? const Uuid();

  Directory get tonesDir => Directory(p.join(assetsDir.path, 'tones'));
  File get tonesMetaFile => File(p.join(assetsDir.path, 'tones.json'));

  /// Memastikan folder assets dan tones.json tersedia, serta pulihkan *.tmp yatim
  Future<void> init() async {
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
    }
  }

  Future<void> _atomicWrite(File target, Map<String, dynamic> json) async {
    await AtomicFileWriter.writeJson(target, json, uuid: _uuid);
  }

  /// Membaca daftar nada dari tones.json
  Future<List<ToneRef>> getTones() async {
    if (!tonesMetaFile.existsSync()) {
      await init();
      return [];
    }
    try {
      final text = await tonesMetaFile.readAsString();
      final map = jsonDecode(text) as Map<String, dynamic>;
      final list = map['tones'] as List<dynamic>? ?? [];
      return list
          .map((e) => ToneRefModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ToneRef?> getToneById(String id) async {
    final list = await getTones();
    try {
      return list.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Menambahkan nada baru dari file yang dipilih pengguna
  Future<ToneRef> addTone({
    required File sourceFile,
    required String name,
    String? contentUri,
  }) async {
    await init();

    final size = await sourceFile.length();
    // Batas 10 MB (10 * 1024 * 1024 bytes)
    if (size > 10 * 1024 * 1024) {
      throw ToneFileSizeLimitException(size);
    }

    final ext = p.extension(sourceFile.path).toLowerCase();
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
      } catch (_) {}
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
      } catch (_) {}
    }
    return count;
  }

  /// Mengembalikan task yang memakai nada ke Bawaan Sistem (null)
  Future<void> resetToneInTasks(String toneId) async {
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
      } catch (_) {}
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
        } catch (_) {
          updatedTones.add(tone);
        }
      } else {
        updatedTones.add(tone);
      }
    }
    await _saveTonesMeta(updatedTones);
  }
}
