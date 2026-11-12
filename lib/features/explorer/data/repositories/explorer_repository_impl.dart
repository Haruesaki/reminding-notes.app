import '../../../notes/domain/services/reminder_sync_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/explorer_repository.dart';
import '../datasources/local_storage_data_source.dart';

class ExplorerRepositoryImpl implements ExplorerRepository {
  final LocalStorageDataSource localDataSource;
  final ReminderSyncService? reminderSyncService;

  ExplorerRepositoryImpl({
    required this.localDataSource,
    this.reminderSyncService,
  });

  @override
  Future<List<NodeEntry>> getFolderContents(String relativePath) {
    return localDataSource.listFolder(relativePath);
  }

  @override
  Future<Folder> getFolder(String relativePath) {
    return localDataSource.getFolder(relativePath);
  }

  @override
  Future<Folder> createFolder({required String name, String parentRelativePath = ''}) {
    return localDataSource.createFolder(
      name: name,
      parentRelativePath: parentRelativePath,
    );
  }

  @override
  Future<Folder> renameFolder({required String folderRelativePath, required String newName}) {
    return localDataSource.renameFolder(
      folderRelativePath: folderRelativePath,
      newName: newName,
    );
  }

  @override
  Future<FileEntry> renameFile({required String fileRelativePath, required String newTitle}) async {
    final renamed = await localDataSource.renameFile(
      fileRelativePath: fileRelativePath,
      newTitle: newTitle,
    );
    if (renamed is ListFile && reminderSyncService != null) {
      await reminderSyncService!.syncListFile(renamed);
    }
    return renamed;
  }

  @override
  Future<PageFile> savePage(PageFile page, {String? targetFolderRelativePath}) {
    return localDataSource.writePage(
      page,
      targetFolderRelativePath: targetFolderRelativePath,
    );
  }

  @override
  Future<PageFile> getPage(String relativePath) {
    return localDataSource.readPage(relativePath);
  }

  @override
  Future<ListFile> saveList(ListFile listFile, {String? targetFolderRelativePath}) async {
    ListFile? previousList;
    if (reminderSyncService != null && listFile.relativePath.isNotEmpty) {
      try {
        previousList = await localDataSource.readList(listFile.relativePath);
      } catch (_) {}
    }
    final saved = await localDataSource.writeList(
      listFile,
      targetFolderRelativePath: targetFolderRelativePath,
    );
    if (reminderSyncService != null) {
      await reminderSyncService!.syncListFile(saved, previousList: previousList);
    }
    return saved;
  }

  @override
  Future<ListFile> getList(String relativePath) {
    return localDataSource.readList(relativePath);
  }

  @override
  Future<void> deleteEntry(NodeEntry entry) async {
    List<ListFile> affectedLists = const [];
    if (reminderSyncService != null) {
      if (entry.isFolder) {
        affectedLists = await localDataSource.collectListFilesRecursive(entry.relativePath);
      } else if (entry is ListFile) {
        try {
          affectedLists = [await localDataSource.readList(entry.relativePath)];
        } catch (_) {
          affectedLists = [entry];
        }
      }
    }
    await localDataSource.deleteEntry(entry);
    if (reminderSyncService != null) {
      if (entry.isFolder) {
        await reminderSyncService!.cancelFolderReminders(affectedLists);
      } else if (affectedLists.isNotEmpty) {
        await reminderSyncService!.cancelListFileReminders(affectedLists.first);
      }
    }
  }

  @override
  Future<NodeEntry> moveEntry({
    required NodeEntry entry,
    required String destinationFolderRelativePath,
  }) async {
    final moved = await localDataSource.moveEntry(
      entry: entry,
      destinationFolderRelativePath: destinationFolderRelativePath,
    );
    if (reminderSyncService != null) {
      if (moved is ListFile) {
        await reminderSyncService!.syncListFile(moved);
      } else if (moved is Folder) {
        final affected = await localDataSource.collectListFilesRecursive(moved.relativePath);
        for (final listFile in affected) {
          await reminderSyncService!.syncListFile(listFile);
        }
      }
    }
    return moved;
  }

  @override
  Future<FileEntry> copyFile({
    required FileEntry file,
    required String destinationFolderRelativePath,
  }) async {
    final copied = await localDataSource.copyFile(
      file: file,
      destinationFolderRelativePath: destinationFolderRelativePath,
    );
    if (copied is ListFile && reminderSyncService != null) {
      await reminderSyncService!.syncListFile(copied);
    }
    return copied;
  }

  @override
  Future<FileEntry> toggleFavorite(FileEntry file) {
    return localDataSource.toggleFavorite(file);
  }

  @override
  Future<void> saveOrder({
    required String folderRelativePath,
    required List<String> newOrder,
  }) {
    return localDataSource.saveOrder(
      folderRelativePath: folderRelativePath,
      newOrder: newOrder,
    );
  }

  @override
  Future<List<DeadlineItem>> getAllDeadlines() async {
    final indexManager = localDataSource.indexManager;
    if (indexManager == null) return [];
    var data = await indexManager.loadIndex();
    if (data.files.isEmpty && data.deadlines.isEmpty) {
      data = await indexManager.rebuildIndex(localDataSource.rootDir);
    }
    final fileMap = {for (final f in data.files) f.id: f};
    return data.deadlines.map((d) {
      final file = fileMap[d.fileId];
      return DeadlineItem(
        taskId: d.taskId,
        fileId: d.fileId,
        taskText: d.taskText,
        fileTitle: file?.title ?? 'Catatan',
        fileRelativePath: file?.relativePath ?? '',
        fileType: file?.type ?? 'list',
        at: d.at,
        done: d.done,
      );
    }).toList();
  }

  @override
  Future<List<SearchResultItem>> searchGlobal(String query) {
    return localDataSource.searchGlobal(query);
  }
}
