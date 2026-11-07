import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/database/app_database.dart';
import 'package:reminding/features/notes/data/datasources/note_local_data_source.dart';
import 'package:reminding/features/notes/data/repositories/note_repository_impl.dart';
import 'package:reminding/features/notes/domain/entities/note.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late NoteLocalDataSource localDataSource;
  late NoteRepositoryImpl repository;

  setUp(() async {
    db = await AppDatabase.initDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    localDataSource = NoteLocalDataSourceImpl(db);
    repository = NoteRepositoryImpl(localDataSource);
  });

  tearDown(() async {
    await db.close();
  });

  test('Note CRUD works as expected through repository and local data source', () async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-1',
      title: 'Belajar Flutter',
      content: 'Mempelajari Flutter BLoC dan SQLite',
      category: 'Work',
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Save (Insert)
    await repository.saveNote(note);

    // 2. Fetch by ID
    final fetched = await repository.getNoteById('test-1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Belajar Flutter');
    expect(fetched.content, 'Mempelajari Flutter BLoC dan SQLite');
    expect(fetched.category, 'Work');
    expect(fetched.isPinned, false);

    // 3. Update
    final updatedNote = note.copyWith(
      title: 'Belajar Flutter & Architecture',
      updatedAt: now.add(const Duration(minutes: 5)),
    );
    await repository.saveNote(updatedNote);

    final fetchedUpdated = await repository.getNoteById('test-1');
    expect(fetchedUpdated!.title, 'Belajar Flutter & Architecture');

    // 4. Pin
    await repository.togglePin('test-1', true);
    final pinned = await repository.getNoteById('test-1');
    expect(pinned!.isPinned, true);

    // 5. Query Search
    final searchResults = await repository.getNotes(query: 'Architecture');
    expect(searchResults.length, 1);
    expect(searchResults.first.id, 'test-1');

    final searchMiss = await repository.getNotes(query: 'NonExistent');
    expect(searchMiss.isEmpty, true);

    // 6. Delete (Soft delete)
    await repository.deleteNote('test-1');
    final afterDelete = await repository.getNoteById('test-1');
    expect(afterDelete, isNull);

    final listAfterDelete = await repository.getNotes();
    expect(listAfterDelete.isEmpty, true);
  });
}
