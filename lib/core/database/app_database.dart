import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String databaseName = 'reminding.db';
  static const int databaseVersion = 1;

  static Future<Database> initDatabase({DatabaseFactory? factory, String? overridePath}) async {
    final dbFactory = factory ?? databaseFactory;
    final path = overridePath ?? p.join(await dbFactory.getDatabasesPath(), databaseName);

    return await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL DEFAULT '',
              content TEXT NOT NULL DEFAULT '',
              category TEXT,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              reminder_at TEXT,
              is_archived INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_notes_is_pinned ON notes(is_pinned, updated_at DESC)',
          );
          await db.execute(
            'CREATE INDEX idx_notes_created_at ON notes(created_at)',
          );
        },
      ),
    );
  }
}
