import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/data/datasources/notes_index_manager.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late Directory tempSupportDir;
  late NotesIndexManager indexManager;
  late LocalStorageDataSource dataSource;

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('index_test_root_');
    tempSupportDir = await Directory.systemTemp.createTemp('index_test_support_');
    indexManager = NotesIndexManager(supportDir: tempSupportDir);
    dataSource = LocalStorageDataSource(
      rootDir: tempRootDir,
      indexManager: indexManager,
    );
    await dataSource.init();
  });

  tearDown(() async {
    if (await tempRootDir.exists()) {
      await tempRootDir.delete(recursive: true);
    }
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  group('NotesIndexManager (PRD 6.8)', () {
    test('stores index in supportDir/index.json separate from rootDir', () async {
      await indexManager.saveIndex(
        AppIndexData(
          files: [
            IndexFileEntry(
              id: 'idx_1',
              relativePath: 'Doc1.json',
              type: 'page',
              title: 'Title One',
              plainText: 'Hello snippet',
              favoritedAt: null,
              updatedAt: DateTime.now().toUtc(),
              colorIndex: 0,
            ),
          ],
        ),
      );

      final indexFile = File(p.join(tempSupportDir.path, 'index.json'));
      expect(await indexFile.exists(), isTrue);

      // Verify it does NOT exist in rootDir
      final rootIndexFile = File(p.join(tempRootDir.path, 'index.json'));
      expect(await rootIndexFile.exists(), isFalse);

      final content = await indexFile.readAsString();
      final decoded = json.decode(content) as Map<String, dynamic>;
      expect(decoded['files'], isList);
      expect((decoded['files'] as List).length, 1);
    });

    test('rebuildIndex() reconstructs files and deadlines from files on disk', () async {
      // 1. Create files on disk via dataSource
      final page1 = PageFile(
        id: 'rebuild_p1',
        relativePath: 'Article.json',
        title: 'Article on Architecture',
        plainText: 'Clean architecture in Flutter with local JSON files',
        colorIndex: 0,
        favoritedAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await dataSource.writePage(page1);

      final deadlineTime = DateTime.utc(2025, 4, 1, 10, 0);
      final list1 = ListFile(
        id: 'rebuild_l1',
        relativePath: 'Project Tasks.json',
        title: 'Project Tasks',
        tasks: [
          const Task(id: 't1', text: 'Define entity models'),
          Task(
            id: 't2',
            text: 'Write migration runner',
            deadline: DeadlineSettings(at: deadlineTime),
          ),
        ],
        colorIndex: 1,
        favoritedAt: null,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await dataSource.writeList(list1);

      // Subfolder with a file
      await dataSource.createFolder(parentRelativePath: '', name: 'Sub');
      final page2 = PageFile(
        id: 'rebuild_p2',
        relativePath: 'Sub/Deep Note.json',
        title: 'Deep Note',
        plainText: 'Inside a nested directory',
        colorIndex: 2,
        favoritedAt: null,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await dataSource.writePage(page2, targetFolderRelativePath: 'Sub');

      // 2. Corrupt or delete the index file completely
      final indexFile = File(p.join(tempSupportDir.path, 'index.json'));
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
      expect(await indexFile.exists(), isFalse);

      // 3. Rebuild index from root directory
      final rebuilt = await indexManager.rebuildIndex(tempRootDir);

      // Verify index was regenerated on disk
      expect(await indexFile.exists(), isTrue);

      // Verify entries in returned data
      expect(rebuilt.files.length, 3);
      expect(rebuilt.files.map((e) => e.id), containsAll(['rebuild_p1', 'rebuild_l1', 'rebuild_p2']));

      // Verify page content indexed
      final indexedPage = rebuilt.files.firstWhere((e) => e.id == 'rebuild_p1');
      expect(indexedPage.title, 'Article on Architecture');
      expect(indexedPage.plainText, contains('Clean architecture'));
      expect(indexedPage.favoritedAt, isNotNull);

      // Verify list tasks aggregated in plainText
      final indexedList = rebuilt.files.firstWhere((e) => e.id == 'rebuild_l1');
      expect(indexedList.plainText, contains('Define entity models'));
      expect(indexedList.plainText, contains('Write migration runner'));

      // Verify deadline index
      expect(rebuilt.deadlines.length, 1);
      final dl = rebuilt.deadlines.first;
      expect(dl.taskId, 't2');
      expect(dl.fileId, 'rebuild_l1');
      expect(dl.taskText, 'Write migration runner');

      // 4. Verify loading saved index from disk matches
      final loaded = await indexManager.loadIndex();
      expect(loaded.files.length, 3);
      expect(loaded.deadlines.length, 1);
    });
  });
}
