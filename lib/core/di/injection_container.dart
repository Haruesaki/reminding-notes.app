import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/backup/data/services/backup_service.dart';
import '../../features/explorer/data/datasources/local_storage_data_source.dart';
import '../../features/explorer/data/datasources/notes_index_manager.dart';
import '../../features/explorer/data/repositories/explorer_repository_impl.dart';
import '../../features/explorer/domain/repositories/explorer_repository.dart';
import '../../features/explorer/domain/usecases/explorer_usecases.dart';
import '../../features/notes/data/datasources/tones_local_data_source.dart';
import '../../features/notes/data/services/alarm_service.dart';
import '../../features/notes/data/services/media_store_service.dart';
import '../../features/notes/data/services/notification_service.dart';
import '../../features/notes/data/services/permission_service.dart';
import '../../features/notes/presentation/bloc/list_editor/list_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../features/notes/presentation/bloc/tones/tones_bloc.dart';
import '../../features/notes/presentation/cubit/copy_move_cubit.dart';
import '../../features/notes/presentation/cubit/deadline_calendar_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies({
  Directory? overrideNotesDir,
  Directory? overrideSupportDir,
}) async {
  await sl.reset();

  final Directory notesDir;
  final Directory supportDir;
  final Directory assetsDir;

  if (overrideNotesDir != null && overrideSupportDir != null) {
    notesDir = overrideNotesDir;
    supportDir = overrideSupportDir;
    assetsDir = Directory(p.join(overrideNotesDir.parent.path, 'notes_assets'));
  } else {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    notesDir = Directory(p.join(docs.path, 'notes_data'));
    supportDir = support;
    assetsDir = Directory(p.join(docs.path, 'notes_assets'));
  }

  // Data Sources
  final indexManager = NotesIndexManager(supportDir: supportDir);
  final localDataSource = LocalStorageDataSource(
    rootDir: notesDir,
    indexManager: indexManager,
  );
  await localDataSource.init();

  final mediaStoreService = MediaStoreService();
  final tonesDataSource = TonesLocalDataSource(
    assetsDir: assetsDir,
    notesDir: notesDir,
    mediaStoreService: mediaStoreService,
  );
  await tonesDataSource.init();

  final notificationService = NotificationService();
  await notificationService.init();

  sl.registerSingleton<NotesIndexManager>(indexManager);
  sl.registerSingleton<LocalStorageDataSource>(localDataSource);
  sl.registerSingleton<MediaStoreService>(mediaStoreService);
  sl.registerSingleton<TonesLocalDataSource>(tonesDataSource);
  sl.registerSingleton<NotificationService>(notificationService);
  sl.registerLazySingleton<AlarmService>(() => AlarmService());
  sl.registerLazySingleton<PermissionService>(() => PermissionService());
  sl.registerLazySingleton<BackupService>(() => BackupService());
  sl.registerSingleton<Directory>(notesDir, instanceName: 'notesDir');
  sl.registerSingleton<Directory>(assetsDir, instanceName: 'assetsDir');

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
  sl.registerFactory<TonesBloc>(
    () => TonesBloc(dataSource: sl<TonesLocalDataSource>()),
  );
  sl.registerFactory<DeadlineCalendarCubit>(
    () => DeadlineCalendarCubit(repository: sl<ExplorerRepository>()),
  );
  sl.registerLazySingleton<CopyMoveCubit>(
    () => CopyMoveCubit(),
  );
}

