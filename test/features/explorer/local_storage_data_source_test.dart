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
    tempRootDir = await Directory.systemTemp.createTemp('storage_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('storage_support_test_');
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

  group('LocalStorageDataSource (PRD 6.4 - 6.6)', () {
    test('init() initializes root directory and root _folder.json', () async {
      final rootMeta = File(p.join(tempRootDir.path, '_folder.json'));
      expect(await rootMeta.exists(), isTrue);

      final contents = await dataSource.listFolder('');
      expect(contents, isEmpty);
    });

    test('atomic write writes UTF-8 without BOM, ends with newline, leaves no .tmp', () async {
      final page = PageFile(
        id: 'p_atomic',
        relativePath: 'Atomic Note.json',
        title: 'Atomic Note',
        plainText: 'Atomic test content',
        colorIndex: 1,
        favoritedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.writePage(page);

      final file = File(p.join(tempRootDir.path, 'Atomic Note.json'));
      expect(await file.exists(), isTrue);

      // Check no .tmp file remains
      final tmpFile = File(p.join(tempRootDir.path, 'Atomic Note.json.tmp'));
      expect(await tmpFile.exists(), isFalse);

      // Check raw bytes: no BOM (UTF-8 BOM is [0xEF, 0xBB, 0xBF])
      final bytes = await file.readAsBytes();
      expect(bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF, isFalse);

      // Check ends with \n (0x0A)
      expect(bytes.last, equals(0x0A));

      // Check content decode
      final decoded = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(decoded['id'], 'p_atomic');
      expect(decoded['title'], 'Atomic Note');
    });

    test('round-trip save and read PageFile', () async {
      final now = DateTime.utc(2025, 2, 1, 14, 30);
      final deltaContent = [
        {'insert': 'Hello world!\n'},
        {'insert': 'Bold text', 'attributes': {'bold': true}}
      ];

      final page = PageFile(
        id: 'page_123',
        relativePath: 'Greeting.json',
        title: 'Greeting',
        content: deltaContent,
        plainText: 'Hello world!\nBold text',
        colorIndex: 3,
        favoritedAt: now,
        createdAt: now,
        updatedAt: now,
        extras: const {'custom_plugin': 42},
      );

      await dataSource.writePage(page);

      final loaded = await dataSource.readPage('Greeting.json');
      expect(loaded.id, 'page_123');
      expect(loaded.title, 'Greeting');
      expect(loaded.content, deltaContent);
      expect(loaded.plainText, 'Hello world!\nBold text');
      expect(loaded.colorIndex, 3);
      expect(loaded.favoritedAt, now);
      expect(loaded.isFavorite, isTrue);
      expect(loaded.extras['custom_plugin'], 42);
    });

    test('round-trip save and read ListFile with tasks, deadlines, and alarms', () async {
      final now = DateTime.utc(2025, 3, 10, 8, 0);
      final deadline = DateTime(2025, 3, 15, 17, 0);

      final list = ListFile(
        id: 'list_123',
        relativePath: 'Sprint Tasks.json',
        title: 'Sprint Tasks',
        tasks: [
          Task(
            id: 't1',
            text: 'Setup repository',
            done: true,
            subtasks: const [
              Subtask(id: 'st1', text: 'Init git', done: true),
              Subtask(id: 'st2', text: 'Add PRD', done: true),
            ],
            deadline: DeadlineSettings(
              at: deadline,
              remindStartDaysBefore: 1,
              remindTimes: const ['09:00', '14:00'],
              notificationToneId: 'tone_bell',
            ),
            alarm: AlarmSettings(
              enabled: true,
              at: deadline,
              toneId: 'alarm_loud',
            ),
          ),
          const Task(
            id: 't2',
            text: 'Build features',
            done: false,
          ),
        ],
        colorIndex: 2,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );

      await dataSource.writeList(list);

      final loaded = await dataSource.readList('Sprint Tasks.json');
      expect(loaded.id, 'list_123');
      expect(loaded.title, 'Sprint Tasks');
      expect(loaded.tasks.length, 2);

      final task1 = loaded.tasks.first;
      expect(task1.id, 't1');
      expect(task1.text, 'Setup repository');
      expect(task1.done, isTrue);
      expect(task1.subtasks.length, 2);
      expect(task1.subtasks.first.text, 'Init git');
      expect(task1.subtasks.first.done, isTrue);

      expect(task1.deadline, isNotNull);
      expect(task1.deadline!.at, deadline);
      expect(task1.deadline!.remindTimes, ['09:00', '14:00']);

      expect(task1.alarm, isNotNull);
      expect(task1.alarm!.enabled, isTrue);
      expect(task1.alarm!.toneId, 'alarm_loud');

      final task2 = loaded.tasks[1];
      expect(task2.id, 't2');
      expect(task2.done, isFalse);
    });

    test('folder operations: create, rename, delete recursive, save order', () async {
      // 1. Create folder
      final createdFolder = await dataSource.createFolder(
        parentRelativePath: '',
        name: 'Work Projects',
      );
      expect(createdFolder.name, 'Work Projects');
      expect(createdFolder.relativePath, 'Work Projects');

      final metaFile = File(p.join(tempRootDir.path, 'Work Projects', '_folder.json'));
      expect(await metaFile.exists(), isTrue);

      // 2. Rename folder
      final renamedFolder = await dataSource.renameFolder(
        folderRelativePath: 'Work Projects',
        newName: 'Office Work',
      );
      expect(renamedFolder.name, 'Office Work');
      expect(renamedFolder.relativePath, 'Office Work');
      expect(await metaFile.exists(), isFalse);
      final newMetaFile = File(p.join(tempRootDir.path, 'Office Work', '_folder.json'));
      expect(await newMetaFile.exists(), isTrue);

      // 3. Save order in root
      await dataSource.saveOrder(
        folderRelativePath: '',
        newOrder: [renamedFolder.id],
      );
      final rootFolder = await dataSource.getFolder('');
      expect(rootFolder.order, [renamedFolder.id]);

      // 4. Delete folder
      await dataSource.deleteEntry(renamedFolder);
      expect(await Directory(p.join(tempRootDir.path, 'Office Work')).exists(), isFalse);
    });

    test('file operations: rename, move, copy, delete, toggle favorite', () async {
      final now = DateTime.now();
      final page = PageFile(
        id: 'p_ops',
        relativePath: 'Doc.json',
        title: 'Doc',
        plainText: 'Operations test',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      final savedPage = await dataSource.writePage(page);

      // 1. Toggle favorite
      final favPage = await dataSource.toggleFavorite(savedPage);
      expect(favPage.isFavorite, isTrue);
      expect(favPage.favoritedAt, isNotNull);

      final unFavPage = await dataSource.toggleFavorite(favPage);
      expect(unFavPage.isFavorite, isFalse);
      expect(unFavPage.favoritedAt, isNull);

      // 2. Rename file
      final renamed = await dataSource.renameFile(
        fileRelativePath: unFavPage.relativePath,
        newTitle: 'Manual',
      );
      expect(renamed.title, 'Manual');
      expect(renamed.relativePath, 'Manual.json');
      expect(await File(p.join(tempRootDir.path, 'Doc.json')).exists(), isFalse);
      expect(await File(p.join(tempRootDir.path, 'Manual.json')).exists(), isTrue);

      // 3. Copy file
      final copied = await dataSource.copyFile(
        file: renamed,
        destinationFolderRelativePath: '',
      );
      expect(copied.id, isNot('p_ops')); // New ID
      expect(copied.title, 'Manual (2)');
      expect(copied.relativePath, 'Manual (2).json');
      expect(await File(p.join(tempRootDir.path, 'Manual (2).json')).exists(), isTrue);

      // 4. Move file into subfolder
      await dataSource.createFolder(parentRelativePath: '', name: 'Archive');
      await dataSource.moveEntry(
        entry: copied,
        destinationFolderRelativePath: 'Archive',
      );
      expect(await File(p.join(tempRootDir.path, 'Archive', 'Manual (2).json')).exists(), isTrue);
      expect(await File(p.join(tempRootDir.path, 'Manual (2).json')).exists(), isFalse);

      // 5. Delete file
      final movedPage = await dataSource.readPage(p.join('Archive', 'Manual (2).json').replaceAll(r'\', '/'));
      await dataSource.deleteEntry(movedPage);
      expect(await File(p.join(tempRootDir.path, 'Archive', 'Manual (2).json')).exists(), isFalse);
    });
  });
}
