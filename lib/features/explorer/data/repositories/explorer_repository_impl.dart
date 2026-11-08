import '../../domain/entities/entities.dart';
import '../../domain/repositories/explorer_repository.dart';
import '../datasources/local_storage_data_source.dart';

class ExplorerRepositoryImpl implements ExplorerRepository {
  final LocalStorageDataSource localDataSource;

  ExplorerRepositoryImpl({required this.localDataSource});

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
  Future<FileEntry> renameFile({required String fileRelativePath, required String newTitle}) {
    return localDataSource.renameFile(
      fileRelativePath: fileRelativePath,
      newTitle: newTitle,
    );
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
  Future<ListFile> saveList(ListFile listFile, {String? targetFolderRelativePath}) {
    return localDataSource.writeList(
      listFile,
      targetFolderRelativePath: targetFolderRelativePath,
    );
  }

  @override
  Future<ListFile> getList(String relativePath) {
    return localDataSource.readList(relativePath);
  }

  @override
  Future<void> deleteEntry(NodeEntry entry) {
    return localDataSource.deleteEntry(entry);
  }

  @override
  Future<void> moveEntry({
    required NodeEntry entry,
    required String destinationFolderRelativePath,
  }) {
    return localDataSource.moveEntry(
      entry: entry,
      destinationFolderRelativePath: destinationFolderRelativePath,
    );
  }

  @override
  Future<FileEntry> copyFile({
    required FileEntry file,
    required String destinationFolderRelativePath,
  }) {
    return localDataSource.copyFile(
      file: file,
      destinationFolderRelativePath: destinationFolderRelativePath,
    );
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
