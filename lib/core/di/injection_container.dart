import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../migration/data_access_mode.dart';
import '../migration/migration_runner.dart';
import '../../features/backup/data/services/backup_service.dart';
import '../../features/explorer/data/datasources/local_storage_data_source.dart';
import '../../features/explorer/data/datasources/notes_index_manager.dart';
import '../../features/explorer/data/repositories/explorer_repository_impl.dart';
import '../../features/explorer/domain/repositories/explorer_repository.dart';
import '../../features/explorer/domain/usecases/explorer_usecases.dart';
import '../../features/notes/data/datasources/tones_local_data_source.dart';
import '../../features/notes/data/services/alarm_service.dart';
import '../../features/notes/data/services/media_store_service.dart';
import '../../features/notes/data/services/notification_plugin_client.dart';
import '../../features/notes/data/services/notification_service.dart';
import '../../features/notes/data/services/permission_service.dart';
import '../../features/notes/data/services/reminder_sync_service_impl.dart';
import '../../features/notes/domain/services/reminder_sync_service.dart';
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
  MigrationRunner? migrationRunner,
  NotificationPluginClient? notificationPluginClient,
  Future<String> Function()? timezoneProvider,
  bool reconcileOnStart = true,
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

  final dataAccessMode = DataAccessMode();
  final runner = migrationRunner ?? MigrationRunner();
  final tonesFile = File(p.join(assetsDir.path, 'tones.json'));

  try {
    final migrationResult = await runner.migrateStartup(
      notesDir: notesDir,
      tonesFile: tonesFile,
    );
    if (migrationResult.hasNewerSchemaVersion) {
      dataAccessMode.markReadOnly(
        detectedVersion: migrationResult.maxDetectedVersion,
      );
    }
  } catch (e) {
    dataAccessMode.setMigrationError(
      e is MigrationFailedException
          ? (e.cause != null ? '${e.message}: ${e.cause}' : e.message)
          : e.toString(),
    );
  }

  // Data Sources
  final indexManager = NotesIndexManager(
    supportDir: supportDir,
    dataAccessMode: dataAccessMode,
  );
  final localDataSource = LocalStorageDataSource(
    rootDir: notesDir,
    indexManager: indexManager,
    dataAccessMode: dataAccessMode,
  );
  await localDataSource.init();

  final mediaStoreService = MediaStoreService();
  final tonesDataSource = TonesLocalDataSource(
    assetsDir: assetsDir,
    notesDir: notesDir,
    mediaStoreService: mediaStoreService,
    dataAccessMode: dataAccessMode,
  );
  await tonesDataSource.init();

  final notificationService = NotificationService(
    pluginClient: notificationPluginClient,
    timezoneProvider: timezoneProvider,
  );
  await notificationService.init();

  final reminderSyncService = ReminderSyncServiceImpl(
    notesDir: notesDir,
    supportDir: supportDir,
    indexManager: indexManager,
    localDataSource: localDataSource,
    tonesDataSource: tonesDataSource,
    notificationService: notificationService,
    dataAccessMode: dataAccessMode,
  );

  sl.registerSingleton<DataAccessMode>(dataAccessMode);
  sl.registerSingleton<NotesIndexManager>(indexManager);
  sl.registerSingleton<LocalStorageDataSource>(localDataSource);
  sl.registerSingleton<MediaStoreService>(mediaStoreService);
  sl.registerSingleton<TonesLocalDataSource>(tonesDataSource);
  sl.registerSingleton<NotificationService>(notificationService);
  sl.registerSingleton<ReminderSyncService>(reminderSyncService);
  sl.registerLazySingleton<AlarmService>(() => AlarmService());
  sl.registerLazySingleton<PermissionService>(() => PermissionService());
  sl.registerLazySingleton<BackupService>(
    () => BackupService(
      dataAccessMode: sl<DataAccessMode>(),
      indexManager: sl<NotesIndexManager>(),
      tonesDataSource: sl<TonesLocalDataSource>(),
      reminderSyncService: sl<ReminderSyncService>(),
    ),
  );
  sl.registerSingleton<Directory>(notesDir, instanceName: 'notesDir');
  sl.registerSingleton<Directory>(assetsDir, instanceName: 'assetsDir');
  sl.registerSingleton<Directory>(supportDir, instanceName: 'supportDir');

  // Repositories
  sl.registerLazySingleton<ExplorerRepository>(
    () => ExplorerRepositoryImpl(
      localDataSource: sl<LocalStorageDataSource>(),
      reminderSyncService: sl<ReminderSyncService>(),
    ),
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
    () => NoteEditorBloc(
      repository: sl<ExplorerRepository>(),
      dataAccessMode: sl<DataAccessMode>(),
    ),
  );
  sl.registerFactory<ListEditorBloc>(
    () => ListEditorBloc(
      repository: sl<ExplorerRepository>(),
      reminderSyncService: sl<ReminderSyncService>(),
      dataAccessMode: sl<DataAccessMode>(),
    ),
  );
  sl.registerFactory<TonesBloc>(
    () => TonesBloc(
      dataSource: sl<TonesLocalDataSource>(),
      reminderSyncService: sl<ReminderSyncService>(),
    ),
  );
  sl.registerFactory<DeadlineCalendarCubit>(
    () => DeadlineCalendarCubit(repository: sl<ExplorerRepository>()),
  );
  sl.registerLazySingleton<CopyMoveCubit>(
    () => CopyMoveCubit(),
  );

  if (reconcileOnStart && !dataAccessMode.hasMigrationError) {
    await reminderSyncService.reconcileAllReminders();
  }
}

