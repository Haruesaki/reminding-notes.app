import '../entities/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes({
    DateTime? selectedDate,
    String? query,
    String? category,
  });
  Future<Note?> getNoteById(String id);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> togglePin(String id, bool isPinned);
}
