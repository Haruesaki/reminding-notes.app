import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../features/notes/data/datasources/note_local_data_source.dart';
import '../../features/notes/data/repositories/note_repository_impl.dart';
import '../../features/notes/domain/repositories/note_repository.dart';
import '../../features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_list/note_list_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies({Database? overrideDb}) async {
  // Database
  final Database database = overrideDb ?? await AppDatabase.initDatabase();
  sl.registerSingleton<Database>(database);

  // Data Sources
  sl.registerLazySingleton<NoteLocalDataSource>(
    () => NoteLocalDataSourceImpl(sl<Database>()),
  );

  // Repositories
  sl.registerLazySingleton<NoteRepository>(
    () => NoteRepositoryImpl(sl<NoteLocalDataSource>()),
  );

  // Blocs
  sl.registerFactory<NoteListBloc>(
    () => NoteListBloc(repository: sl<NoteRepository>()),
  );
  sl.registerFactory<NoteEditorBloc>(
    () => NoteEditorBloc(repository: sl<NoteRepository>()),
  );
}

