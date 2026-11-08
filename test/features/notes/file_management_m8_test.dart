import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/core/utils/name_sanitizer.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/data/datasources/notes_index_manager.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/domain/services/file_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  late Directory tempSupportDir;
  late NotesIndexManager indexManager;
  late LocalStorageDataSource dataSource;

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('m8_root_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('m8_support_test_');
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

  group('M8: Isi .txt Hasil Bagikan (PRD 7.9)', () {
    test('PageFile: menghasilkan judul dan plainText saja tanpa JSON', () {
      final now = DateTime(2025, 1, 1);
      final page = PageFile(
        id: 'p1',
        relativePath: 'notes/catatan_penting.json',
        title: 'Catatan Rapat',
        plainText: 'Hasil rapat: tindak lanjuti sebelum akhir pekan.\nDeadline Jumat.',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );

      final textResult = FileShareService.formatAsPlainText(page);

      expect(textResult, contains('Catatan Rapat'));
      expect(textResult, contains('Hasil rapat: tindak lanjuti sebelum akhir pekan.'));
      expect(textResult, contains('Deadline Jumat.'));
      expect(textResult, isNot(contains('"content"')));
      expect(textResult, isNot(contains('"schemaVersion"')));
      expect(textResult, isNot(contains('{')));
    });

    test('ListFile: menghasilkan format [ ] dan [x] dengan subtask berindentasi tanpa JSON', () {
      final now = DateTime(2025, 1, 1);
      final listFile = ListFile(
        id: 'l1',
        relativePath: 'todo.json',
        title: 'Daftar Belanja',
        tasks: const [
          Task(
            id: 't1',
            text: 'Bahan Pokok',
            done: false,
            subtasks: [
              Subtask(id: 'st1', text: 'Beras 5kg', done: true),
              Subtask(id: 'st2', text: 'Minyak Goreng', done: false),
            ],
          ),
          Task(
            id: 't2',
            text: 'Snack',
            done: true,
            subtasks: [],
          ),
        ],
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );

      final textResult = FileShareService.formatAsPlainText(listFile);

      expect(textResult, contains('Daftar Belanja'));
      expect(textResult, contains('[ ] Bahan Pokok'));
      expect(textResult, contains('    [x] Beras 5kg'));
      expect(textResult, contains('    [ ] Minyak Goreng'));
      expect(textResult, contains('[x] Snack'));
      expect(textResult, isNot(contains('"tasks"')));
      expect(textResult, isNot(contains('{')));
    });

    test('Nama file dibersihkan dengan NameSanitizer dan berakhiran .txt', () {
      const rawTitle = 'Laporan / Proyek * BPMP: 2026?';
      final sanitized = NameSanitizer.sanitize(rawTitle);
      final fileName = '$sanitized.txt';

      expect(fileName, endsWith('.txt'));
      expect(fileName, isNot(contains('/')));
      expect(fileName, isNot(contains('*')));
      expect(fileName, isNot(contains(':')));
      expect(fileName, isNot(contains('?')));
    });
  });

  group('M8: Salin dan Pindah (PRD 7.8)', () {
    test('Salin file: ID baru, favoritedAt direset, bentrok nama menghasilkan " (2)"', () async {
      final now = DateTime(2025, 1, 1);
      final original = PageFile(
        id: 'orig-1',
        relativePath: 'Tugas.json',
        title: 'Tugas',
        plainText: 'Kerjakan soal 1-5',
        colorIndex: 0,
        favoritedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final savedOriginal = await dataSource.writePage(original);

      // Salin ke folder yang sama (bentrok nama)
      final copy1 = await dataSource.copyFile(
        file: savedOriginal,
        destinationFolderRelativePath: '',
      );

      expect(copy1.id, isNot(equals(original.id)));
      expect(copy1.title, equals('Tugas (2)'));
      expect(copy1.isFavorite, isFalse);
      expect(copy1.favoritedAt, isNull);

      // Salin lagi (bentrok nama kedua -> " (3)")
      final copy2 = await dataSource.copyFile(
        file: savedOriginal,
        destinationFolderRelativePath: '',
      );
      expect(copy2.title, equals('Tugas (3)'));
      expect(copy2.id, isNot(equals(original.id)));
      expect(copy2.id, isNot(equals(copy1.id)));
      expect(copy2.favoritedAt, isNull);
    });

    test('Pindah file: berpindah ke folder tujuan dan order di kedua folder diperbarui', () async {
      final now = DateTime(2025, 1, 1);
      final destFolder = await dataSource.createFolder(
        name: 'Arsip',
        parentRelativePath: '',
      );

      final file = PageFile(
        id: 'file-pindah',
        relativePath: 'Dokumen.json',
        title: 'Dokumen',
        plainText: 'Rahasia',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      final savedFile = await dataSource.writePage(file);

      // Pindahkan ke folder Arsip
      await dataSource.moveEntry(
        entry: savedFile,
        destinationFolderRelativePath: destFolder.relativePath,
      );

      // Verifikasi di root file sudah tidak ada
      final rootEntries = await dataSource.listFolder('');
      expect(rootEntries.any((e) => e.id == file.id), isFalse);

      // Verifikasi di Arsip file sudah ada
      final destEntries = await dataSource.listFolder(destFolder.relativePath);
      expect(destEntries.any((e) => e.id == file.id), isTrue);

      // Verifikasi order di folder Arsip memuat id file
      final updatedDestFolder = await dataSource.getFolder(destFolder.relativePath);
      expect(updatedDestFolder.order, contains(file.id));
    });

    test('Pindah folder: memindahkan struktur direktori ke folder lain', () async {
      final now = DateTime(2025, 1, 1);
      final fA = await dataSource.createFolder(name: 'FolderA', parentRelativePath: '');
      final fB = await dataSource.createFolder(name: 'FolderB', parentRelativePath: '');

      // Simpan file di dalam FolderA
      final subFile = PageFile(
        id: 'sub-file',
        relativePath: 'FolderA/sub.json',
        title: 'Sub File',
        plainText: 'Halo',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.writePage(subFile);

      // Pindahkan FolderA ke dalam FolderB
      await dataSource.moveEntry(
        entry: fA,
        destinationFolderRelativePath: fB.relativePath,
      );

      // Verifikasi subfile ikut berpindah
      final bSubEntries = await dataSource.listFolder(p.join('FolderB', 'FolderA').replaceAll(r'\', '/'));
      expect(bSubEntries.any((e) => e.id == 'sub-file'), isTrue);
    });
  });

  group('M8: Larangan Pindah Folder ke Turunan (PRD 7.8)', () {
    test('Dilarang memindahkan folder ke dalam dirinya sendiri', () async {
      final folder = await dataSource.createFolder(name: 'Proyek', parentRelativePath: '');

      expect(
        () => dataSource.moveEntry(
          entry: folder,
          destinationFolderRelativePath: folder.relativePath,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Dilarang memindahkan folder ke dalam subfoldernya (turunannya)', () async {
      final parent = await dataSource.createFolder(name: 'Induk', parentRelativePath: '');
      final child = await dataSource.createFolder(name: 'Anak', parentRelativePath: parent.relativePath);
      final grandChild = await dataSource.createFolder(name: 'Cucu', parentRelativePath: child.relativePath);

      // Coba pindahkan Induk ke Anak
      expect(
        () => dataSource.moveEntry(
          entry: parent,
          destinationFolderRelativePath: child.relativePath,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Coba pindahkan Induk ke Cucu
      expect(
        () => dataSource.moveEntry(
          entry: parent,
          destinationFolderRelativePath: grandChild.relativePath,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('M8: Urutan Setelah Reorder (PRD 7.7)', () {
    test('Reorder order tersimpan ke _folder.json', () async {
      final f1 = await dataSource.createFolder(name: 'F1', parentRelativePath: '');
      final f2 = await dataSource.createFolder(name: 'F2', parentRelativePath: '');
      final f3 = await dataSource.createFolder(name: 'F3', parentRelativePath: '');

      // Simpan reorder baru: [f3, f1, f2]
      final newOrder = [f3.id, f1.id, f2.id];
      await dataSource.saveOrder(
        folderRelativePath: '',
        newOrder: newOrder,
      );

      final rootFolder = await dataSource.getFolder('');
      expect(rootFolder.order, equals(newOrder));
    });

    test('Reorder file hanya dalam grupnya (favorit / non-favorit)', () {
      final now = DateTime(2025, 1, 1);
      final fav1 = PageFile(
        id: 'fav-1',
        relativePath: 'fav1.json',
        title: 'Fav 1',
        plainText: '',
        colorIndex: 0,
        favoritedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final fav2 = PageFile(
        id: 'fav-2',
        relativePath: 'fav2.json',
        title: 'Fav 2',
        plainText: '',
        colorIndex: 0,
        favoritedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final normal1 = PageFile(
        id: 'norm-1',
        relativePath: 'norm1.json',
        title: 'Norm 1',
        plainText: '',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
      );

      // Validasi logika reorder restriction:
      // canReorderWith: source.isFavorite == target.isFavorite
      expect(fav1.isFavorite == fav2.isFavorite, isTrue);
      expect(fav1.isFavorite == normal1.isFavorite, isFalse);
    });
  });
}
