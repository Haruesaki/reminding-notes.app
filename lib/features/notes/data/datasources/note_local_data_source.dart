import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';

abstract class NoteLocalDataSource {
  Future<List<NoteModel>> getNotes({
    DateTime? selectedDate,
    String? query,
    String? category,
  });
  Future<NoteModel?> getNoteById(String id);
  Future<void> insertNote(NoteModel note);
  Future<void> updateNote(NoteModel note);
  Future<void> deleteNote(String id);
  Future<void> togglePin(String id, bool isPinned);
}

class NoteLocalDataSourceImpl implements NoteLocalDataSource {
  final Database database;

  NoteLocalDataSourceImpl(this.database);

  static const String tableName = 'notes';

  @override
  Future<List<NoteModel>> getNotes({
    DateTime? selectedDate,
    String? query,
    String? category,
  }) async {
    final whereClauses = <String>['is_archived = 0'];
    final whereArgs = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR content LIKE ?)');
      final searchPattern = '%${query.trim()}%';
      whereArgs.add(searchPattern);
      whereArgs.add(searchPattern);
    }

    if (category != null && category.trim().isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category.trim());
    }

    if (selectedDate != null) {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      whereClauses.add('created_at >= ? AND created_at < ?');
      whereArgs.add(startOfDay.toIso8601String());
      whereArgs.add(endOfDay.toIso8601String());
    }

    final maps = await database.query(
      tableName,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return maps.map((map) => NoteModel.fromMap(map)).toList();
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    final maps = await database.query(
      tableName,
      where: 'id = ? AND is_archived = 0',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return NoteModel.fromMap(maps.first);
  }

  @override
  Future<void> insertNote(NoteModel note) async {
    await database.insert(
      tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    await database.update(
      tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    // Soft delete according to PRD 5.1 is_archived flag
    await database.update(
      tableName,
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> togglePin(String id, bool isPinned) async {
    await database.update(
      tableName,
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
