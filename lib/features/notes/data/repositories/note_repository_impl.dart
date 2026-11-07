import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/note_local_data_source.dart';
import '../models/note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  final NoteLocalDataSource localDataSource;

  NoteRepositoryImpl(this.localDataSource);

  @override
  Future<List<Note>> getNotes({
    DateTime? selectedDate,
    String? query,
    String? category,
  }) async {
    return await localDataSource.getNotes(
      selectedDate: selectedDate,
      query: query,
      category: category,
    );
  }

  @override
  Future<Note?> getNoteById(String id) async {
    return await localDataSource.getNoteById(id);
  }

  @override
  Future<void> saveNote(Note note) async {
    final model = NoteModel.fromEntity(note);
    final existing = await localDataSource.getNoteById(note.id);
    if (existing != null) {
      await localDataSource.updateNote(model);
    } else {
      await localDataSource.insertNote(model);
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    await localDataSource.deleteNote(id);
  }

  @override
  Future<void> togglePin(String id, bool isPinned) async {
    await localDataSource.togglePin(id, isPinned);
  }
}
