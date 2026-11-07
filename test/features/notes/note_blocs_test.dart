import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/database/app_database.dart';
import 'package:reminding/features/notes/data/datasources/note_local_data_source.dart';
import 'package:reminding/features/notes/data/repositories/note_repository_impl.dart';
import 'package:reminding/features/notes/domain/entities/note.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_state.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late NoteRepositoryImpl repository;

  setUp(() async {
    db = await AppDatabase.initDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    final localDataSource = NoteLocalDataSourceImpl(db);
    repository = NoteRepositoryImpl(localDataSource);
  });

  tearDown(() async {
    await db.close();
  });

  group('NoteListBloc', () {
    test('initial state is NoteListInitial', () {
      final bloc = NoteListBloc(repository: repository);
      expect(bloc.state, equals(NoteListInitial()));
      bloc.close();
    });

    blocTest<NoteListBloc, NoteListState>(
      'emits [NoteListLoading, NoteListLoaded] when LoadNotes is added',
      build: () => NoteListBloc(repository: repository),
      act: (bloc) => bloc.add(const LoadNotes()),
      expect: () => [
        isA<NoteListLoading>(),
        isA<NoteListLoaded>().having((s) => s.notes, 'notes', isEmpty),
      ],
    );

    blocTest<NoteListBloc, NoteListState>(
      'filters notes by search query correctly',
      build: () => NoteListBloc(repository: repository),
      setUp: () async {
        final now = DateTime.now();
        await repository.saveNote(Note(
          id: 'n1',
          title: 'Design Review',
          content: 'Figma review meeting',
          createdAt: now,
          updatedAt: now,
        ));
      },
      act: (bloc) => bloc.add(const SearchNotes('Design')),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<NoteListLoaded>().having((s) => s.notes.length, 'notes count', 1),
      ],
    );
  });

  group('NoteEditorBloc', () {
    test('initial state is NoteEditorInitial', () {
      final bloc = NoteEditorBloc(repository: repository);
      expect(bloc.state, equals(NoteEditorInitial()));
      bloc.close();
    });

    test('initializes new note properly and saves it', () async {
      final bloc = NoteEditorBloc(repository: repository);

      bloc.add(const InitializeNote());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const UpdateTitle('Grocery Shopping'));
      bloc.add(const UpdateContent('Apples, Milk, Bread'));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const SaveNoteEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      final all = await repository.getNotes();
      expect(all.length, 1);
      expect(all.first.title, 'Grocery Shopping');
      expect(all.first.content, 'Apples, Milk, Bread');

      await bloc.close();
    });
  });
}
