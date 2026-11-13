import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/core/utils/app_logger.dart';

import '../../../../core/migration/data_access_mode.dart';
import '../../../../core/migration/migration_runner.dart';
import '../../../../core/utils/atomic_file_writer.dart';

class IndexFileEntry extends Equatable {
  final String id;
  final String relativePath;
  final String type; // 'page' or 'list'
  final String title;
  final String plainText;
  final DateTime? favoritedAt;
  final DateTime updatedAt;
  final int colorIndex;

  const IndexFileEntry({
    required this.id,
    required this.relativePath,
    required this.type,
    required this.title,
    required this.plainText,
    required this.favoritedAt,
    required this.updatedAt,
    required this.colorIndex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'relativePath': relativePath,
        'type': type,
        'title': title,
        'plainText': plainText,
        'favoritedAt': favoritedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'colorIndex': colorIndex,
      };

  factory IndexFileEntry.fromMap(Map<String, dynamic> map) {
    return IndexFileEntry(
      id: map['id'] as String? ?? '',
      relativePath: map['relativePath'] as String? ?? '',
      type: map['type'] as String? ?? 'page',
      title: map['title'] as String? ?? '',
      plainText: map['plainText'] as String? ?? '',
      favoritedAt: map['favoritedAt'] != null
          ? DateTime.tryParse(map['favoritedAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      colorIndex: map['colorIndex'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        relativePath,
        type,
        title,
        plainText,
        favoritedAt,
        updatedAt,
        colorIndex,
      ];

  IndexFileEntry copyWith({
    String? id,
    String? relativePath,
    String? type,
    String? title,
    String? plainText,
    DateTime? favoritedAt,
    DateTime? updatedAt,
    int? colorIndex,
  }) {
    return IndexFileEntry(
      id: id ?? this.id,
      relativePath: relativePath ?? this.relativePath,
      type: type ?? this.type,
      title: title ?? this.title,
      plainText: plainText ?? this.plainText,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}

class IndexDeadlineEntry extends Equatable {
  final String taskId;
  final String fileId;
  final String taskText;
  final DateTime at;
  final bool done;

  const IndexDeadlineEntry({
    required this.taskId,
    required this.fileId,
    required this.taskText,
    required this.at,
    required this.done,
  });

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'fileId': fileId,
        'taskText': taskText,
        'at': at.toIso8601String(),
        'done': done,
      };

  factory IndexDeadlineEntry.fromMap(Map<String, dynamic> map) {
    return IndexDeadlineEntry(
      taskId: map['taskId'] as String? ?? '',
      fileId: map['fileId'] as String? ?? '',
      taskText: map['taskText'] as String? ?? '',
      at: map['at'] != null ? DateTime.parse(map['at'] as String) : DateTime.now(),
      done: map['done'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [taskId, fileId, taskText, at, done];
}

class AppIndexData extends Equatable {
  static const int currentVersion = 1;

  final int version;
  final List<IndexFileEntry> files;
  final List<IndexDeadlineEntry> deadlines;

  const AppIndexData({
    this.version = currentVersion,
    this.files = const [],
    this.deadlines = const [],
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'files': files.map((f) => f.toMap()).toList(),
        'deadlines': deadlines.map((d) => d.toMap()).toList(),
      };

  factory AppIndexData.fromMap(Map<String, dynamic> map) {
    final v = map['version'] as int? ?? currentVersion;
    final filesList = (map['files'] as List<dynamic>? ?? [])
        .map((e) => IndexFileEntry.fromMap(e as Map<String, dynamic>))
        .toList();
    final deadlinesList = (map['deadlines'] as List<dynamic>? ?? [])
        .map((e) => IndexDeadlineEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    return AppIndexData(
      version: v,
      files: filesList,
      deadlines: deadlinesList,
    );
  }

  @override
  List<Object?> get props => [version, files, deadlines];
}

class NotesIndexManager {
  final Directory supportDir;
  final DataAccessMode? dataAccessMode;

  NotesIndexManager({
    required this.supportDir,
    this.dataAccessMode,
  });

  File get indexFile => File(p.join(supportDir.path, 'index.json'));

  // Penulisan indeks ke disk dilakukan langsung (atomik) pada setiap mutasi tunggal.
  // Tidak ada timer debounce yang tersisa setelah siklus hidup tes/widget berakhir.
  AppIndexData? _cache;
  bool _cacheLoaded = false;

  void _inspectSchemaVersion(Map<String, dynamic> map) {
    final version = (map['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > MigrationRunner.currentSchemaVersion) {
      dataAccessMode?.markReadOnly(detectedVersion: version);
    }
  }

  /// Muat indeks dari cache memori; bila belum ada, baca dari disk sekali.
  Future<AppIndexData> loadIndex() async {
    if (dataAccessMode?.hasMigrationError == true) {
      return const AppIndexData();
    }
    if (_cacheLoaded && _cache != null) {
      return _cache!;
    }
    final file = indexFile;
    if (dataAccessMode?.isReadOnly != true) {
      await AtomicFileWriter.recoverTargetOrphans(file);
    }
    if (!await file.exists()) {
      _cache = const AppIndexData();
      _cacheLoaded = true;
      return const AppIndexData();
    }
    try {
      final content = await file.readAsString(encoding: utf8);
      final jsonMap = json.decode(content) as Map<String, dynamic>;
      final data = AppIndexData.fromMap(jsonMap);
      if (data.version != AppIndexData.currentVersion) {
        _cache = const AppIndexData();
        _cacheLoaded = true;
        return const AppIndexData();
      }
      _cache = data;
      _cacheLoaded = true;
      return data;
    } catch (e, st) {
      AppLogger.error(e, st);
      // Jika corrupt atau rusak, kembalikan kosong agar dibangun ulang
      _cache = const AppIndexData();
      _cacheLoaded = true;
      return const AppIndexData();
    }
  }

  Future<void> saveIndex(AppIndexData data) async {
    dataAccessMode?.ensureWritable();
    await AtomicFileWriter.writeJson(indexFile, data.toMap());
    _cache = data;
    _cacheLoaded = true;
  }

  /// Tulis indeks ke disk secara atomik pada setiap mutasi tunggal.
  /// Penulisan diserialisasi oleh [AtomicFileWriter], jadi tidak perlu antrean
  /// tambahan di sini. Tidak ada timer debounce, sehingga tidak tersisa timer
  /// pending setelah siklus hidup tes atau widget berakhir.
  Future<void> _persistIndex(AppIndexData data) async {
    _cache = data;
    _cacheLoaded = true;
    await saveIndex(data);
  }

  /// Upsert satu entri berkas ke indeks (create atau update).
  Future<void> upsertEntry(IndexFileEntry entry) async {
    await loadIndex();
    final data = _cache!;
    final idx = data.files.indexWhere((f) => f.id == entry.id);
    final updatedFiles = List<IndexFileEntry>.from(data.files);
    if (idx >= 0) {
      updatedFiles[idx] = entry;
    } else {
      updatedFiles.add(entry);
    }
    final newData = AppIndexData(
      version: AppIndexData.currentVersion,
      files: updatedFiles,
      deadlines: data.deadlines,
    );
    _cache = newData;
    _cacheLoaded = true;
    await _persistIndex(newData);
  }

  /// Hapus satu entri dari indeks berdasarkan relativePath.
  Future<void> removeEntry(String relativePath) async {
    await loadIndex();
    final data = _cache!;
    final updatedFiles = data.files.where((f) => f.relativePath != relativePath).toList();
    final updatedDeadlines = data.deadlines.where((d) {
      final file = updatedFiles.firstWhere((f) => f.id == d.fileId, orElse: () => IndexFileEntry(
        id: '',
        relativePath: '',
        type: 'page',
        title: '',
        plainText: '',
        favoritedAt: null,
        updatedAt: DateTime.now(),
        colorIndex: 0,
      ));
      return file.id.isNotEmpty;
    }).toList();
    final newData = AppIndexData(
      version: AppIndexData.currentVersion,
      files: updatedFiles,
      deadlines: updatedDeadlines,
    );
    _cache = newData;
    _cacheLoaded = true;
    await _persistIndex(newData);
  }

  /// Hapus semua entri di bawah folder (subtree).
  Future<void> removeSubtree(String folderRelativePath) async {
    await loadIndex();
    final data = _cache!;
    final normFolder = folderRelativePath.replaceAll(r'\', '/');
    final removedIds = <String>{};
    final updatedFiles = data.files.where((f) {
      final rel = f.relativePath.replaceAll(r'\', '/');
      final isInside = rel == normFolder ||
          rel.startsWith('$normFolder/');
      if (isInside) removedIds.add(f.id);
      return !isInside;
    }).toList();
    final updatedDeadlines = data.deadlines.where((d) => !removedIds.contains(d.fileId)).toList();
    final newData = AppIndexData(
      version: AppIndexData.currentVersion,
      files: updatedFiles,
      deadlines: updatedDeadlines,
    );
    _cache = newData;
    _cacheLoaded = true;
    await _persistIndex(newData);
  }

  /// Pindahkan satu entri dari path lama ke path baru di indeks.
  Future<void> moveEntry(String oldRelativePath, String newRelativePath) async {
    await loadIndex();
    final data = _cache!;
    final normOld = oldRelativePath.replaceAll(r'\', '/');
    final normNew = newRelativePath.replaceAll(r'\', '/');
    final updatedFiles = data.files.map((f) {
      final rel = f.relativePath.replaceAll(r'\', '/');
      if (rel == normOld) {
        return f.copyWith(relativePath: normNew);
      }
      return f;
    }).toList();
    final newData = AppIndexData(
      version: AppIndexData.currentVersion,
      files: updatedFiles,
      deadlines: data.deadlines,
    );
    _cache = newData;
    _cacheLoaded = true;
    await _persistIndex(newData);
  }

  /// Pindahkan seluruh subtree folder dari path lama ke path baru.
  Future<void> moveSubtree(String oldFolderRelativePath, String newFolderRelativePath) async {
    await loadIndex();
    final data = _cache!;
    final normOld = oldFolderRelativePath.replaceAll(r'\', '/');
    final normNew = newFolderRelativePath.replaceAll(r'\', '/');
    final prefix = '$normOld/';
    final updatedFiles = data.files.map((f) {
      final rel = f.relativePath.replaceAll(r'\', '/');
      if (rel == normOld) {
        return f.copyWith(relativePath: normNew);
      }
      if (rel.startsWith(prefix)) {
        return f.copyWith(relativePath: '$normNew${rel.substring(normOld.length)}');
      }
      return f;
    }).toList();
    final newData = AppIndexData(
      version: AppIndexData.currentVersion,
      files: updatedFiles,
      deadlines: data.deadlines,
    );
    _cache = newData;
    _cacheLoaded = true;
    await _persistIndex(newData);
  }

  /// Membangun ulang indeks dari pohon direktori notes_data secara lengkap
  Future<AppIndexData> rebuildIndex(Directory notesDataDir) async {
    if (dataAccessMode?.hasMigrationError == true) {
      return const AppIndexData();
    }
    final files = <IndexFileEntry>[];
    final deadlines = <IndexDeadlineEntry>[];

    if (!await notesDataDir.exists()) {
      const empty = AppIndexData();
      if (dataAccessMode?.isReadOnly != true) {
        await saveIndex(empty);
      }
      _cache = empty;
      _cacheLoaded = true;
      return empty;
    }

    final entities = await notesDataDir.exists()
        ? await notesDataDir.list(recursive: true, followLinks: false).toList()
        : <FileSystemEntity>[];
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = p.basename(entity.path);
        if (filename.endsWith('.tmp') || filename.endsWith('.bak')) {
          continue;
        }
        if (filename == '_folder.json') {
          try {
            final content = await entity.readAsString(encoding: utf8);
            final map = json.decode(content) as Map<String, dynamic>;
            _inspectSchemaVersion(map);
          } catch (_) {}
          continue;
        }

        try {
          final content = await entity.readAsString(encoding: utf8);
          final map = json.decode(content) as Map<String, dynamic>;
          _inspectSchemaVersion(map);
          final type = map['type'] as String? ?? 'page';
          final id = map['id'] as String? ?? '';
          final title = map['title'] as String? ?? '';
          final colorIndex = map['colorIndex'] as int? ?? 0;
          final favoritedAt = map['favoritedAt'] != null
              ? DateTime.tryParse(map['favoritedAt'] as String)
              : null;
          final updatedAt = map['updatedAt'] != null
              ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
              : DateTime.now();

          final relativePath = p.relative(entity.path, from: notesDataDir.path).replaceAll(r'\', '/');

          if (type == 'page') {
            final plainText = map['plainText'] as String? ?? '';
            files.add(IndexFileEntry(
              id: id,
              relativePath: relativePath,
              type: 'page',
              title: title,
              plainText: plainText,
              favoritedAt: favoritedAt,
              updatedAt: updatedAt,
              colorIndex: colorIndex,
            ));
          } else if (type == 'list') {
            final tasksList = (map['tasks'] as List<dynamic>? ?? []);
            final taskTexts = <String>[];
            for (final t in tasksList) {
              if (t is Map<String, dynamic>) {
                final taskId = t['id'] as String? ?? '';
                final taskText = t['text'] as String? ?? '';
                final done = t['done'] as bool? ?? false;
                taskTexts.add(taskText);

                final dl = t['deadline'] as Map<String, dynamic>?;
                if (dl != null && dl['at'] != null) {
                  final at = DateTime.tryParse(dl['at'] as String);
                  if (at != null) {
                    deadlines.add(IndexDeadlineEntry(
                      taskId: taskId,
                      fileId: id,
                      taskText: taskText,
                      at: at,
                      done: done,
                    ));
                  }
                }
              }
            }
            files.add(IndexFileEntry(
              id: id,
              relativePath: relativePath,
              type: 'list',
              title: title,
              plainText: taskTexts.join(' • '),
              favoritedAt: favoritedAt,
              updatedAt: updatedAt,
              colorIndex: colorIndex,
            ));
          }
        } catch (e, st) {
          AppLogger.error(e, st);
          // Abaikan file yang korup saat indeksasi
        }
      }
    }

    final newIndex = AppIndexData(
      version: AppIndexData.currentVersion,
      files: files,
      deadlines: deadlines,
    );

    if (dataAccessMode?.isReadOnly != true) {
      await saveIndex(newIndex);
    }
    _cache = newIndex;
    _cacheLoaded = true;
    return newIndex;
  }

}
