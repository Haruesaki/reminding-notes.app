import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/explorer/data/datasources/local_storage_data_source.dart';
import '../../features/explorer/data/datasources/notes_index_manager.dart';
import '../../features/explorer/data/repositories/explorer_repository_impl.dart';
import '../../features/explorer/domain/repositories/explorer_repository.dart';
import '../../features/explorer/domain/usecases/explorer_usecases.dart';
import '../../features/notes/presentation/bloc/list_editor/list_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies({
  Directory? overrideNotesDir,
  Directory? overrideSupportDir,
}) async {
  await sl.reset();

  final Directory notesDir;
  final Directory supportDir;

  if (overrideNotesDir != null && overrideSupportDir != null) {
    notesDir = overrideNotesDir;
    supportDir = overrideSupportDir;
  } else {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    notesDir = Directory(p.join(docs.path, 'notes_data'));
    supportDir = support;
  }

  // Data Sources
  final indexManager = NotesIndexManager(supportDir: supportDir);
  final localDataSource = LocalStorageDataSource(
    rootDir: notesDir,
    indexManager: indexManager,
  );
  await localDataSource.init();

  sl.registerSingleton<NotesIndexManager>(indexManager);
  sl.registerSingleton<LocalStorageDataSource>(localDataSource);

  // Repositories
  sl.registerLazySingleton<ExplorerRepository>(
    () => ExplorerRepositoryImpl(localDataSource: sl<LocalStorageDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetFolderContentsUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => CreateFolderUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => RenameFolderUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => RenameFileUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => SavePageUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => GetPageUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => SaveListUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => GetListUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => DeleteEntryUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => MoveEntryUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => CopyFileUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => ToggleFavoriteUseCase(sl<ExplorerRepository>()));
  sl.registerLazySingleton(() => SaveOrderUseCase(sl<ExplorerRepository>()));

  // Blocs
  sl.registerFactory<NoteListBloc>(
    () => NoteListBloc(repository: sl<ExplorerRepository>()),
  );
  sl.registerFactory<NoteEditorBloc>(
    () => NoteEditorBloc(repository: sl<ExplorerRepository>()),
  );
  sl.registerFactory<ListEditorBloc>(
    () => ListEditorBloc(repository: sl<ExplorerRepository>()),
  );
}

