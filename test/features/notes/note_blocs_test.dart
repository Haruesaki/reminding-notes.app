import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/data/datasources/notes_index_manager.dart';
import 'package:reminding/features/explorer/data/repositories/explorer_repository_impl.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_state.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;
  late LocalStorageDataSource localDataSource;
  late ExplorerRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('note_blocs_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('note_blocs_support_test_');
    final indexManager = NotesIndexManager(supportDir: tempSupportDir);
    localDataSource = LocalStorageDataSource(
      rootDir: tempDir,
      indexManager: indexManager,
    );
    await localDataSource.init();
    repository = ExplorerRepositoryImpl(localDataSource: localDataSource);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
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
      wait: const Duration(milliseconds: 100),
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
        await repository.savePage(PageFile(
          id: 'p1',
          relativePath: 'Design Review.json',
          title: 'Design Review',
          plainText: 'Figma review meeting',
          colorIndex: 0,
          favoritedAt: null,
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
      await Future.delayed(const Duration(milliseconds: 150));

      final all = await repository.getFolderContents('');
      final files = all.whereType<PageFile>().toList();
      expect(files.length, 1);
      expect(files.first.title, 'Grocery Shopping');
      expect(files.first.plainText, 'Apples, Milk, Bread');

      await bloc.close();
    });
  });
}
