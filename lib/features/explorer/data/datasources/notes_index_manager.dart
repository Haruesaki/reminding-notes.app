import 'dart:convert';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

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

  NotesIndexManager({required this.supportDir});

  File get indexFile => File(p.join(supportDir.path, 'index.json'));

  Future<AppIndexData> loadIndex() async {
    final file = indexFile;
    if (!await file.exists()) {
      return const AppIndexData();
    }
    try {
      final content = await file.readAsString(encoding: utf8);
      final jsonMap = json.decode(content) as Map<String, dynamic>;
      final data = AppIndexData.fromMap(jsonMap);
      if (data.version != AppIndexData.currentVersion) {
        return const AppIndexData();
      }
      return data;
    } catch (_) {
      // Jika corrupt atau rusak, kembalikan kosong agar dibangun ulang
      return const AppIndexData();
    }
  }

  Future<void> saveIndex(AppIndexData data) async {
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }
    final file = indexFile;
    final tmpFile = File('${file.path}.tmp');
    final jsonStr = '${const JsonEncoder.withIndent('  ').convert(data.toMap())}\n';

    await tmpFile.writeAsString(jsonStr, encoding: utf8, flush: true);
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

  /// Membangun ulang indeks dari pohon direktori notes_data secara lengkap
  Future<AppIndexData> rebuildIndex(Directory notesDataDir) async {
    final files = <IndexFileEntry>[];
    final deadlines = <IndexDeadlineEntry>[];

    if (!await notesDataDir.exists()) {
      final empty = const AppIndexData();
      await saveIndex(empty);
      return empty;
    }

    final entities = notesDataDir.existsSync()
        ? notesDataDir.listSync(recursive: true, followLinks: false)
        : <FileSystemEntity>[];
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = p.basename(entity.path);
        if (filename == '_folder.json' || filename.endsWith('.tmp') || filename.endsWith('.bak')) {
          continue;
        }

        try {
          final content = entity.readAsStringSync(encoding: utf8);
          final map = json.decode(content) as Map<String, dynamic>;
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
        } catch (_) {
          // Abaikan file yang korup saat indeksasi
        }
      }
    }

    final newIndex = AppIndexData(
      version: AppIndexData.currentVersion,
      files: files,
      deadlines: deadlines,
    );

    await saveIndex(newIndex);
    return newIndex;
  }
}
