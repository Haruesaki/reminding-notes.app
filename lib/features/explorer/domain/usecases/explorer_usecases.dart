import '../../../../core/usecase/usecase.dart';
import '../entities/entities.dart';
import '../repositories/explorer_repository.dart';

class GetFolderContentsUseCase implements UseCase<List<NodeEntry>, String> {
  final ExplorerRepository repository;

  GetFolderContentsUseCase(this.repository);

  @override
  Future<List<NodeEntry>> call(String relativePath) {
    return repository.getFolderContents(relativePath);
  }
}

class CreateFolderParams {
  final String name;
  final String parentRelativePath;

  const CreateFolderParams({
    required this.name,
    this.parentRelativePath = '',
  });
}

class CreateFolderUseCase implements UseCase<Folder, CreateFolderParams> {
  final ExplorerRepository repository;

  CreateFolderUseCase(this.repository);

  @override
  Future<Folder> call(CreateFolderParams params) {
    return repository.createFolder(
      name: params.name,
      parentRelativePath: params.parentRelativePath,
    );
  }
}

class RenameFolderParams {
  final String folderRelativePath;
  final String newName;

  const RenameFolderParams({
    required this.folderRelativePath,
    required this.newName,
  });
}

class RenameFolderUseCase implements UseCase<Folder, RenameFolderParams> {
  final ExplorerRepository repository;

  RenameFolderUseCase(this.repository);

  @override
  Future<Folder> call(RenameFolderParams params) {
    return repository.renameFolder(
      folderRelativePath: params.folderRelativePath,
      newName: params.newName,
    );
  }
}

class RenameFileParams {
  final String fileRelativePath;
  final String newTitle;

  const RenameFileParams({
    required this.fileRelativePath,
    required this.newTitle,
  });
}

class RenameFileUseCase implements UseCase<FileEntry, RenameFileParams> {
  final ExplorerRepository repository;

  RenameFileUseCase(this.repository);

  @override
  Future<FileEntry> call(RenameFileParams params) {
    return repository.renameFile(
      fileRelativePath: params.fileRelativePath,
      newTitle: params.newTitle,
    );
  }
}

class SavePageParams {
  final PageFile page;
  final String? targetFolderRelativePath;

  const SavePageParams({
    required this.page,
    this.targetFolderRelativePath,
  });
}

class SavePageUseCase implements UseCase<PageFile, SavePageParams> {
  final ExplorerRepository repository;

  SavePageUseCase(this.repository);

  @override
  Future<PageFile> call(SavePageParams params) {
    return repository.savePage(
      params.page,
      targetFolderRelativePath: params.targetFolderRelativePath,
    );
  }
}

class GetPageUseCase implements UseCase<PageFile, String> {
  final ExplorerRepository repository;

  GetPageUseCase(this.repository);

  @override
  Future<PageFile> call(String relativePath) {
    return repository.getPage(relativePath);
  }
}

class SaveListParams {
  final ListFile listFile;
  final String? targetFolderRelativePath;

  const SaveListParams({
    required this.listFile,
    this.targetFolderRelativePath,
  });
}

class SaveListUseCase implements UseCase<ListFile, SaveListParams> {
  final ExplorerRepository repository;

  SaveListUseCase(this.repository);

  @override
  Future<ListFile> call(SaveListParams params) {
    return repository.saveList(
      params.listFile,
      targetFolderRelativePath: params.targetFolderRelativePath,
    );
  }
}

class GetListUseCase implements UseCase<ListFile, String> {
  final ExplorerRepository repository;

  GetListUseCase(this.repository);

  @override
  Future<ListFile> call(String relativePath) {
    return repository.getList(relativePath);
  }
}

class DeleteEntryUseCase implements UseCase<void, NodeEntry> {
  final ExplorerRepository repository;

  DeleteEntryUseCase(this.repository);

  @override
  Future<void> call(NodeEntry entry) {
    return repository.deleteEntry(entry);
  }
}

class MoveEntryParams {
  final NodeEntry entry;
  final String destinationFolderRelativePath;

  const MoveEntryParams({
    required this.entry,
    required this.destinationFolderRelativePath,
  });
}

class MoveEntryUseCase implements UseCase<void, MoveEntryParams> {
  final ExplorerRepository repository;

  MoveEntryUseCase(this.repository);

  @override
  Future<void> call(MoveEntryParams params) {
    return repository.moveEntry(
      entry: params.entry,
      destinationFolderRelativePath: params.destinationFolderRelativePath,
    );
  }
}

class CopyFileParams {
  final FileEntry file;
  final String destinationFolderRelativePath;

  const CopyFileParams({
    required this.file,
    required this.destinationFolderRelativePath,
  });
}

class CopyFileUseCase implements UseCase<FileEntry, CopyFileParams> {
  final ExplorerRepository repository;

  CopyFileUseCase(this.repository);

  @override
  Future<FileEntry> call(CopyFileParams params) {
    return repository.copyFile(
      file: params.file,
      destinationFolderRelativePath: params.destinationFolderRelativePath,
    );
  }
}

class ToggleFavoriteUseCase implements UseCase<FileEntry, FileEntry> {
  final ExplorerRepository repository;

  ToggleFavoriteUseCase(this.repository);

  @override
  Future<FileEntry> call(FileEntry file) {
    return repository.toggleFavorite(file);
  }
}

class SaveOrderParams {
  final String folderRelativePath;
  final List<String> newOrder;

  const SaveOrderParams({
    required this.folderRelativePath,
    required this.newOrder,
  });
}

class SaveOrderUseCase implements UseCase<void, SaveOrderParams> {
  final ExplorerRepository repository;

  SaveOrderUseCase(this.repository);

  @override
  Future<void> call(SaveOrderParams params) {
    return repository.saveOrder(
      folderRelativePath: params.folderRelativePath,
      newOrder: params.newOrder,
    );
  }
}
