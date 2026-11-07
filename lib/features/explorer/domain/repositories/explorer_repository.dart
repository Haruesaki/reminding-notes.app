import '../entities/entities.dart';

abstract class ExplorerRepository {
  Future<List<NodeEntry>> getFolderContents(String relativePath);
  Future<Folder> getFolder(String relativePath);
  Future<Folder> createFolder({required String name, String parentRelativePath = ''});
  Future<Folder> renameFolder({required String folderRelativePath, required String newName});
  Future<FileEntry> renameFile({required String fileRelativePath, required String newTitle});
  Future<PageFile> savePage(PageFile page, {String? targetFolderRelativePath});
  Future<PageFile> getPage(String relativePath);
  Future<ListFile> saveList(ListFile listFile, {String? targetFolderRelativePath});
  Future<ListFile> getList(String relativePath);
  Future<void> deleteEntry(NodeEntry entry);
  Future<void> moveEntry({required NodeEntry entry, required String destinationFolderRelativePath});
  Future<FileEntry> copyFile({required FileEntry file, required String destinationFolderRelativePath});
  Future<FileEntry> toggleFavorite(FileEntry file);
  Future<void> saveOrder({required String folderRelativePath, required List<String> newOrder});
  Future<List<DeadlineItem>> getAllDeadlines();
}
