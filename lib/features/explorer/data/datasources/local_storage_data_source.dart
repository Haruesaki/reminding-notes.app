import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/utils/display_order_sorter.dart';
import '../../../../core/utils/name_sanitizer.dart';
import '../../domain/entities/entities.dart';
import '../models/folder_model.dart';
import '../models/list_file_model.dart';
import '../models/page_file_model.dart';
import 'notes_index_manager.dart';

class LocalStorageDataSource {
  final Directory rootDir;
  final NotesIndexManager? indexManager;
  final Uuid _uuid;

  LocalStorageDataSource({
    required this.rootDir,
    this.indexManager,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Mengembalikan path absolut dari relativePath
  Directory _resolveDirectory(String relativePath) {
    if (relativePath.isEmpty || relativePath == '.' || relativePath == '/') {
      return rootDir;
    }
    return Directory(p.join(rootDir.path, relativePath));
  }

  File _resolveFile(String relativePath) {
    return File(p.join(rootDir.path, relativePath));
  }

  /// Format JSON standar: UTF-8 tanpa BOM, indent 2 spasi, diakhiri \n
  String _encodeJson(Map<String, dynamic> data) {
    return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
  }

  /// Atomic write: tulis ke *.tmp lalu rename ke target
  Future<void> _atomicWrite(File targetFile, Map<String, dynamic> jsonMap) async {
    final parentDir = targetFile.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    final tmpFile = File('${targetFile.path}.tmp');
    final content = _encodeJson(jsonMap);

    tmpFile.writeAsStringSync(content, flush: true);

    try {
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      tmpFile.renameSync(targetFile.path);
    } catch (_) {
      tmpFile.copySync(targetFile.path);
      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }
    }
  }

  /// Memastikan folder root dan _folder.json root sudah dibuat
  Future<void> init() async {
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final rootMetaFile = File(p.join(rootDir.path, '_folder.json'));
    if (!rootMetaFile.existsSync()) {
      final rootFolder = FolderModel(
        id: 'root',
        relativePath: '',
        name: 'root',
        createdAt: DateTime.now().toUtc(),
        order: const [],
      );
      await _atomicWrite(rootMetaFile, rootFolder.toJson());
    }

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }
  }

  /// Membaca _folder.json dari relative path
  Future<FolderModel> getFolder(String relativePath) async {
    final dir = _resolveDirectory(relativePath);
    if (!dir.existsSync()) {
      throw FileSystemException('Folder not found', dir.path);
    }
    final metaFile = File(p.join(dir.path, '_folder.json'));
    if (!metaFile.existsSync()) {
      // Auto-create jika belum ada
      final folderId = _uuid.v4();
      final folderName = relativePath.isEmpty ? 'root' : p.basename(dir.path);
      final model = FolderModel(
        id: folderId,
        relativePath: relativePath,
        name: folderName,
        createdAt: DateTime.now().toUtc(),
        order: const [],
      );
      await _atomicWrite(metaFile, model.toJson());
      return model;
    }

    final content = metaFile.readAsStringSync(encoding: utf8);
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    return FolderModel.fromJson(jsonMap, relativePath: relativePath);
  }

  /// Daftar isi folder terurut sesuai PRD 6.9
  Future<List<NodeEntry>> listFolder(String relativePath) async {
    final dir = _resolveDirectory(relativePath);
    if (!dir.existsSync()) {
      return [];
    }

    final folderMeta = await getFolder(relativePath);
    final entries = <NodeEntry>[];

    final entities = dir.existsSync() ? dir.listSync(followLinks: false) : <FileSystemEntity>[];
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('_') || name.endsWith('.tmp') || name.endsWith('.bak')) {
        continue;
      }

      final relPath = relativePath.isEmpty ? name : p.join(relativePath, name).replaceAll(r'\', '/');

      if (entity is Directory) {
        // Subfolder
        try {
          final subFolder = await getFolder(relPath);
          entries.add(subFolder);
        } catch (_) {}
      } else if (entity is File && name.endsWith('.json')) {
        try {
          final content = entity.readAsStringSync(encoding: utf8);
          final map = json.decode(content) as Map<String, dynamic>;
          final type = map['type'] as String? ?? 'page';
          if (type == 'page') {
            entries.add(PageFileModel.fromJson(map, relativePath: relPath));
          } else if (type == 'list') {
            entries.add(ListFileModel.fromJson(map, relativePath: relPath));
          }
        } catch (_) {}
      }
    }

    return DisplayOrderSorter.sortEntries(
      entries: entries,
      order: folderMeta.order,
    );
  }

  /// Membaca Page
  Future<PageFileModel> readPage(String relativePath) async {
    final file = _resolveFile(relativePath);
    if (!await file.exists()) {
      throw FileSystemException('Page file not found', file.path);
    }
    final content = await file.readAsString(encoding: utf8);
    final map = json.decode(content) as Map<String, dynamic>;
    return PageFileModel.fromJson(map, relativePath: relativePath);
  }

  /// Membaca List
  Future<ListFileModel> readList(String relativePath) async {
    final file = _resolveFile(relativePath);
    if (!await file.exists()) {
      throw FileSystemException('List file not found', file.path);
    }
    final content = await file.readAsString(encoding: utf8);
    final map = json.decode(content) as Map<String, dynamic>;
    return ListFileModel.fromJson(map, relativePath: relativePath);
  }

  /// Menulis/Menyimpan PageFile
  Future<PageFileModel> writePage(PageFile page, {String? targetFolderRelativePath}) async {
    final folderRel = targetFolderRelativePath ??
        (page.relativePath.contains('/') ? p.dirname(page.relativePath) : '');
    final dir = _resolveDirectory(folderRel);

    // Dapatkan daftar file di folder untuk collision check
    final existingFileNames = <String>[];
    if (await dir.exists()) {
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) existingFileNames.add(p.basename(e.path));
      }
    }

    String fileName;
    if (page.relativePath.isNotEmpty && targetFolderRelativePath == null) {
      // Pertahankan filename yang ada jika update in-place
      fileName = p.basename(page.relativePath);
    } else {
      final sanitizedTitle = NameSanitizer.sanitize(page.title);
      fileName = NameSanitizer.resolveCollision(
        sanitizedTitle,
        existingFileNames,
        extension: '.json',
      );
    }

    final newRelPath = folderRel.isEmpty ? fileName : p.join(folderRel, fileName).replaceAll(r'\', '/');
    final targetFile = _resolveFile(newRelPath);

    final model = PageFileModel.fromEntity(page.copyWith(
      relativePath: newRelPath,
      updatedAt: DateTime.now().toUtc(),
    ));

    await _atomicWrite(targetFile, model.toJson());
    await _ensureInOrder(folderRel, model.id);

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }

    return model;
  }

  /// Menulis/Menyimpan ListFile
  Future<ListFileModel> writeList(ListFile listFile, {String? targetFolderRelativePath}) async {
    final folderRel = targetFolderRelativePath ??
        (listFile.relativePath.contains('/') ? p.dirname(listFile.relativePath) : '');
    final dir = _resolveDirectory(folderRel);

    final existingFileNames = <String>[];
    if (await dir.exists()) {
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) existingFileNames.add(p.basename(e.path));
      }
    }

    String fileName;
    if (listFile.relativePath.isNotEmpty && targetFolderRelativePath == null) {
      fileName = p.basename(listFile.relativePath);
    } else {
      final sanitizedTitle = NameSanitizer.sanitize(listFile.title);
      fileName = NameSanitizer.resolveCollision(
        sanitizedTitle,
        existingFileNames,
        extension: '.json',
      );
    }

    final newRelPath = folderRel.isEmpty ? fileName : p.join(folderRel, fileName).replaceAll(r'\', '/');
    final targetFile = _resolveFile(newRelPath);

    final model = ListFileModel.fromEntity(listFile.copyWith(
      relativePath: newRelPath,
      updatedAt: DateTime.now().toUtc(),
    ));

    await _atomicWrite(targetFile, model.toJson());
    await _ensureInOrder(folderRel, model.id);

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }

    return model;
  }

  /// Membuat folder baru
  Future<FolderModel> createFolder({
    required String name,
    String parentRelativePath = '',
  }) async {
    final parentDir = _resolveDirectory(parentRelativePath);
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final existingDirNames = <String>[];
    await for (final e in parentDir.list(followLinks: false)) {
      if (e is Directory) existingDirNames.add(p.basename(e.path));
    }

    final sanitizedName = NameSanitizer.sanitize(name);
    final dirName = NameSanitizer.resolveCollision(sanitizedName, existingDirNames);

    final newFolderRel = parentRelativePath.isEmpty
        ? dirName
        : p.join(parentRelativePath, dirName).replaceAll(r'\', '/');
    final newDir = _resolveDirectory(newFolderRel);
    await newDir.create(recursive: true);

    final folderId = _uuid.v4();
    final model = FolderModel(
      id: folderId,
      relativePath: newFolderRel,
      name: name,
      createdAt: DateTime.now().toUtc(),
      order: const [],
    );

    final metaFile = File(p.join(newDir.path, '_folder.json'));
    await _atomicWrite(metaFile, model.toJson());

    await _ensureInOrder(parentRelativePath, folderId);
    return model;
  }

  /// Mengganti nama folder
  Future<FolderModel> renameFolder({
    required String folderRelativePath,
    required String newName,
  }) async {
    final oldDir = _resolveDirectory(folderRelativePath);
    if (!await oldDir.exists()) {
      throw FileSystemException('Folder not found', oldDir.path);
    }

    final parentRel = folderRelativePath.contains('/') ? p.dirname(folderRelativePath) : '';
    final parentDir = _resolveDirectory(parentRel);

    final existingNames = <String>[];
    await for (final e in parentDir.list(followLinks: false)) {
      if (e is Directory && p.basename(e.path) != p.basename(oldDir.path)) {
        existingNames.add(p.basename(e.path));
      }
    }

    final sanitized = NameSanitizer.sanitize(newName);
    final targetDirName = NameSanitizer.resolveCollision(sanitized, existingNames);
    final newRelPath = parentRel.isEmpty ? targetDirName : p.join(parentRel, targetDirName).replaceAll(r'\', '/');
    final newDir = _resolveDirectory(newRelPath);

    if (oldDir.path != newDir.path) {
      await oldDir.rename(newDir.path);
    }

    final currentMeta = await getFolder(newRelPath);
    final updatedMeta = currentMeta.copyWith(name: newName, relativePath: newRelPath);
    final metaFile = File(p.join(newDir.path, '_folder.json'));
    await _atomicWrite(metaFile, FolderModel.fromEntity(updatedMeta).toJson());

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }

    return FolderModel.fromEntity(updatedMeta);
  }

  /// Mengganti nama file
  Future<FileEntry> renameFile({
    required String fileRelativePath,
    required String newTitle,
  }) async {
    final file = _resolveFile(fileRelativePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', file.path);
    }

    final parentRel = fileRelativePath.contains('/') ? p.dirname(fileRelativePath) : '';
    final parentDir = _resolveDirectory(parentRel);

    final existingFileNames = <String>[];
    await for (final e in parentDir.list(followLinks: false)) {
      if (e is File && p.basename(e.path) != p.basename(file.path)) {
        existingFileNames.add(p.basename(e.path));
      }
    }

    final sanitized = NameSanitizer.sanitize(newTitle);
    final newFileName = NameSanitizer.resolveCollision(sanitized, existingFileNames, extension: '.json');
    final newRelPath = parentRel.isEmpty ? newFileName : p.join(parentRel, newFileName).replaceAll(r'\', '/');
    final targetFile = _resolveFile(newRelPath);

    final content = await file.readAsString(encoding: utf8);
    final map = json.decode(content) as Map<String, dynamic>;
    map['title'] = newTitle;
    map['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    if (file.path != targetFile.path) {
      await _atomicWrite(targetFile, map);
      if (await file.exists()) {
        await file.delete();
      }
    } else {
      await _atomicWrite(file, map);
    }

    final type = map['type'] as String? ?? 'page';
    final result = type == 'page'
        ? PageFileModel.fromJson(map, relativePath: newRelPath)
        : ListFileModel.fromJson(map, relativePath: newRelPath);

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }

    return result;
  }

  /// Menghapus file atau folder
  Future<void> deleteEntry(NodeEntry entry) async {
    final parentRel = entry.relativePath.contains('/') ? p.dirname(entry.relativePath) : '';

    if (entry.isFolder) {
      final dir = _resolveDirectory(entry.relativePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } else {
      final file = _resolveFile(entry.relativePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _removeFromOrder(parentRel, entry.id);

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }
  }

  /// Memindahkan entri ke folder tujuan
  Future<void> moveEntry({
    required NodeEntry entry,
    required String destinationFolderRelativePath,
  }) async {
    final oldParentRel = entry.relativePath.contains('/') ? p.dirname(entry.relativePath) : '';
    if (oldParentRel == destinationFolderRelativePath) {
      return; // Sudah berada di folder yang sama
    }

    final destDir = _resolveDirectory(destinationFolderRelativePath);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    if (entry.isFolder) {
      final oldDir = _resolveDirectory(entry.relativePath);
      final dirName = p.basename(oldDir.path);
      final newDir = Directory(p.join(destDir.path, dirName));
      await oldDir.rename(newDir.path);
    } else {
      final oldFile = _resolveFile(entry.relativePath);
      final fileName = p.basename(oldFile.path);
      final newFile = File(p.join(destDir.path, fileName));
      if (await newFile.exists()) {
        await newFile.delete();
      }
      await oldFile.rename(newFile.path);
    }

    await _removeFromOrder(oldParentRel, entry.id);
    await _ensureInOrder(destinationFolderRelativePath, entry.id);

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }
  }

  /// Menyalin file ke folder tujuan dengan ID baru
  Future<FileEntry> copyFile({
    required FileEntry file,
    required String destinationFolderRelativePath,
  }) async {
    final newId = _uuid.v4();
    final baseTitle = file.title;
    final destDir = _resolveDirectory(destinationFolderRelativePath);

    final existingNames = <String>[];
    if (await destDir.exists()) {
      await for (final e in destDir.list(followLinks: false)) {
        if (e is File) existingNames.add(p.basename(e.path));
      }
    }

    final sanitized = NameSanitizer.sanitize(baseTitle);
    final newFileName = NameSanitizer.resolveCollision(sanitized, existingNames, extension: '.json');
    final newRelPath = destinationFolderRelativePath.isEmpty
        ? newFileName
        : p.join(destinationFolderRelativePath, newFileName).replaceAll(r'\', '/');

    final newTitle = p.basenameWithoutExtension(newFileName);
    final now = DateTime.now().toUtc();

    if (file is PageFile) {
      final copy = file.copyWith(
        id: newId,
        title: newTitle,
        relativePath: newRelPath,
        createdAt: now,
        updatedAt: now,
      );
      final targetFile = _resolveFile(newRelPath);
      await _atomicWrite(targetFile, PageFileModel.fromEntity(copy).toJson());
      await _ensureInOrder(destinationFolderRelativePath, newId);
      if (indexManager != null) await indexManager!.rebuildIndex(rootDir);
      return copy;
    } else if (file is ListFile) {
      final copy = file.copyWith(
        id: newId,
        title: newTitle,
        relativePath: newRelPath,
        createdAt: now,
        updatedAt: now,
      );
      final targetFile = _resolveFile(newRelPath);
      await _atomicWrite(targetFile, ListFileModel.fromEntity(copy).toJson());
      await _ensureInOrder(destinationFolderRelativePath, newId);
      if (indexManager != null) await indexManager!.rebuildIndex(rootDir);
      return copy;
    }

    throw UnsupportedError('Unsupported file type: ${file.runtimeType}');
  }

  /// Mengubah status favorit sebuah file
  Future<FileEntry> toggleFavorite(FileEntry file) async {
    final isFav = file.isFavorite;
    final updatedFav = isFav ? null : DateTime.now().toUtc();

    final targetFile = _resolveFile(file.relativePath);
    if (!await targetFile.exists()) {
      throw FileSystemException('File not found', targetFile.path);
    }

    final content = await targetFile.readAsString(encoding: utf8);
    final map = json.decode(content) as Map<String, dynamic>;
    map['favoritedAt'] = updatedFav?.toIso8601String();
    map['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await _atomicWrite(targetFile, map);

    FileEntry result;
    if (file is PageFile) {
      result = file.copyWith(
        favoritedAt: updatedFav,
        clearFavoritedAt: updatedFav == null,
        updatedAt: DateTime.now().toUtc(),
      );
    } else if (file is ListFile) {
      result = file.copyWith(
        favoritedAt: updatedFav,
        clearFavoritedAt: updatedFav == null,
        updatedAt: DateTime.now().toUtc(),
      );
    } else {
      throw UnsupportedError('Unknown file type');
    }

    if (indexManager != null) {
      await indexManager!.rebuildIndex(rootDir);
    }

    return result;
  }

  /// Menyimpan urutan baru pada folder
  Future<void> saveOrder({
    required String folderRelativePath,
    required List<String> newOrder,
  }) async {
    final folder = await getFolder(folderRelativePath);
    final updated = folder.copyWith(order: newOrder);
    final metaFile = File(p.join(_resolveDirectory(folderRelativePath).path, '_folder.json'));
    await _atomicWrite(metaFile, FolderModel.fromEntity(updated).toJson());
  }

  // --- Helper privat untuk manajemen order ---

  Future<void> _ensureInOrder(String folderRel, String id) async {
    try {
      final folder = await getFolder(folderRel);
      if (!folder.order.contains(id)) {
        final newOrder = List<String>.from(folder.order)..add(id);
        await saveOrder(folderRelativePath: folderRel, newOrder: newOrder);
      }
    } catch (_) {}
  }

  Future<void> _removeFromOrder(String folderRel, String id) async {
    try {
      final folder = await getFolder(folderRel);
      if (folder.order.contains(id)) {
        final newOrder = List<String>.from(folder.order)..remove(id);
        await saveOrder(folderRelativePath: folderRel, newOrder: newOrder);
      }
    } catch (_) {}
  }
}
