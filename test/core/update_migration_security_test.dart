import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late Directory notesDir;
  late Directory supportDir;

  setUp(() async {
    tempBaseDir = await Directory.systemTemp.createTemp('update_security_test_');
    notesDir = Directory(p.join(tempBaseDir.path, 'notes_data'))..createSync(recursive: true);
    supportDir = Directory(p.join(tempBaseDir.path, 'support_data'))..createSync(recursive: true);
  });

  tearDown(() async {
    if (await tempBaseDir.exists()) {
      await tempBaseDir.delete(recursive: true);
    }
  });

  group('Audit Keamanan Update (PRD 12 & M10)', () {
    test('Skenario update: build lama berisi data lama -> pasang build baru -> data utuh', () async {
      // 1. SIMULASI DATA DARI BUILD LAMA (Build v0.9 / Skema v1 dengan custom extra fields)
      final legacyFolderDir = Directory(p.join(notesDir.path, 'Kuliah'))..createSync();
      final folderMeta = File(p.join(legacyFolderDir.path, '_folder.json'));
      await folderMeta.writeAsString(jsonEncode({
        'schemaVersion': 1,
        'id': 'folder_kuliah_01',
        'name': 'Kuliah',
        'order': ['note_root_01', 'Tugas Besar BPMP'],
        'legacy_tag': 'semester_6',
      }));

      final rootMeta = File(p.join(notesDir.path, '_folder.json'));
      await rootMeta.writeAsString(jsonEncode({
        'schemaVersion': 1,
        'id': 'root',
        'name': '',
        'order': ['Kuliah', 'Catatan Cepat'],
      }));

      final rootNoteFile = File(p.join(notesDir.path, 'Catatan Cepat.json'));
      await rootNoteFile.writeAsString(jsonEncode({
        'schemaVersion': 1,
        'id': 'note_root_01',
        'type': 'page',
        'title': 'Catatan Cepat',
        'content': [
          {'insert': 'Halo dari build lama\n'}
        ],
        'plainText': 'Halo dari build lama',
        'isFavorite': true,
        'favoritedAt': '2026-04-01T10:00:00.000Z',
        'colorIndex': 2,
        'createdAt': '2026-04-01T10:00:00.000Z',
        'updatedAt': '2026-04-01T11:00:00.000Z',
        'unknown_field_kept': 'preserve_me_please',
      }));

      final subtaskNoteFile = File(p.join(legacyFolderDir.path, 'Tugas Besar BPMP.json'));
      await subtaskNoteFile.writeAsString(jsonEncode({
        'schemaVersion': 1,
        'id': 'list_project_01',
        'type': 'list',
        'title': 'Tugas Besar BPMP',
        'isFavorite': false,
        'colorIndex': 0,
        'createdAt': '2026-04-05T08:00:00.000Z',
        'updatedAt': '2026-04-05T09:30:00.000Z',
        'tasks': [
          {
            'id': 'task_1',
            'text': 'Bab 1 Pendahuluan',
            'done': true,
            'subtasks': [
              {
                'id': 'sub_1',
                'text': 'Latar belakang',
                'done': true,
              },
              {
                'id': 'sub_2',
                'text': 'Tujuan & Manfaat',
                'done': true,
              }
            ],
          },
          {
            'id': 'task_2',
            'text': 'Bab 2 Tinjauan Pustaka',
            'done': false,
            'deadline': {
              'targetDate': '2026-05-15T23:59:00.000Z',
              'remindStartDaysBefore': 3,
              'remindTimes': ['09:00', '19:00'],
            },
            'alarm': {
              'enabled': true,
              'at': '2026-05-15T23:59:00.000Z',
              'toneId': 'vintage_bell.mp3',
            },
            'subtasks': [
              {
                'id': 'sub_3',
                'text': 'Studi literatur Flutter',
                'done': false,
              }
            ],
          }
        ],
      }));

      // 2. JALANKAN INISIALISASI BUILD BARU (Injeksi dependensi dan migrasi skema jika ada)
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
      );

      final repo = sl<ExplorerRepository>();

      // 3. VERIFIKASI DATA UTUH DAN STRUKTUR DIKENALI DENGAN BENAR
      final rootEntries = await repo.getFolderContents('');
      expect(rootEntries.length, 2);

      final kuliahFolder = rootEntries.firstWhere((e) => e.isFolder) as Folder;
      expect(kuliahFolder.name, 'Kuliah');

      final rootNote = rootEntries.firstWhere((e) => !e.isFolder) as FileEntry;
      expect(rootNote.title, 'Catatan Cepat');
      expect(rootNote.isFavorite, isTrue);
      expect(rootNote.colorIndex, 2);

      // Verifikasi pembacaan konten Page dan field yang tidak dikenal
      final pageContent = await repo.getPage(rootNote.relativePath);
      expect(pageContent.plainText, 'Halo dari build lama');
      expect(pageContent.extras['unknown_field_kept'], 'preserve_me_please');

      // Verifikasi pembacaan folder bersarang dan List File beserta seluruh task/subtask
      final kuliahEntries = await repo.getFolderContents('Kuliah');
      expect(kuliahEntries.length, 1);

      final listEntry = kuliahEntries.first as FileEntry;
      expect(listEntry.title, 'Tugas Besar BPMP');

      final listContent = await repo.getList(listEntry.relativePath);
      expect(listContent.tasks.length, 2);
      expect(listContent.tasks[0].text, 'Bab 1 Pendahuluan');
      expect(listContent.tasks[0].done, isTrue);
      expect(listContent.tasks[0].subtasks.length, 2);
      expect(listContent.tasks[0].subtasks[0].text, 'Latar belakang');
      expect(listContent.tasks[0].subtasks[0].done, isTrue);

      expect(listContent.tasks[1].text, 'Bab 2 Tinjauan Pustaka');
      expect(listContent.tasks[1].done, isFalse);
      expect(listContent.tasks[1].deadline, isNotNull);
      expect(listContent.tasks[1].deadline?.remindTimes, contains('09:00'));
      expect(listContent.tasks[1].alarm?.toneId, 'vintage_bell.mp3');
      expect(listContent.tasks[1].subtasks.length, 1);
      expect(listContent.tasks[1].subtasks[0].text, 'Studi literatur Flutter');

      // 4. VERIFIKASI MUTASI DATA PADA BUILD BARU TETAP BERSIH DAN AMAN
      final updatedList = listContent.copyWith(
        tasks: [
          ...listContent.tasks,
          const Task(
            id: 'task_3',
            text: 'Bab 3 Metodologi (Ditambah di build baru)',
            done: false,
            subtasks: [],
          ),
        ],
      );
      await repo.saveList(updatedList);

      final reloadedList = await repo.getList(listEntry.relativePath);
      expect(reloadedList.tasks.length, 3);
      expect(reloadedList.tasks[2].text, 'Bab 3 Metodologi (Ditambah di build baru)');

      // File di disk tetap valid JSON tanpa jejak file temporer bocor
      final listFileOnDisk = File(p.join(notesDir.path, 'Kuliah', 'Tugas Besar BPMP.json'));
      expect(await listFileOnDisk.exists(), isTrue);
      final jsonRaw = jsonDecode(await listFileOnDisk.readAsString()) as Map<String, dynamic>;
      expect(jsonRaw['title'], 'Tugas Besar BPMP');
    });

    test('Data pengguna terisolasi: akses di luar LocalStorageDataSource ditolak', () async {
      final dataSource = sl<LocalStorageDataSource>();

      // Path traversal attack "../secret.txt"
      expect(
        () => dataSource.readFile('../outside_notes.json'),
        throwsA(anything),
      );
    });
  });
}
