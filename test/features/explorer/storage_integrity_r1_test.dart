import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/core/utils/atomic_file_writer.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/data/datasources/notes_index_manager.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;
  late LocalStorageDataSource dataSource;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('storage_integrity_test_');
    tempSupportDir = Directory.systemTemp.createTempSync('storage_integrity_support_');
    dataSource = LocalStorageDataSource(
      rootDir: tempDir,
      indexManager: NotesIndexManager(supportDir: tempSupportDir),
    );
    await dataSource.init();
  });

  tearDown(() async {
    AtomicFileWriter.failBeforeRename = false;
    AtomicFileWriter.onBeforeRename = null;
    await AtomicFileWriter.waitForPendingWrites();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    if (tempSupportDir.existsSync()) {
      try {
        tempSupportDir.deleteSync(recursive: true);
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          if (tempSupportDir.existsSync()) tempSupportDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  });

  group('AtomicFileWriter (PRD 6.1, 6.7, R1)', () {
    test('kegagalan sebelum rename -> file target lama utuh isinya', () async {
      final targetFile = File(p.join(tempDir.path, 'important_note.json'));
      final originalData = {'id': 'orig_1', 'title': 'Versi Asli', 'content': 'Utuh'};
      await AtomicFileWriter.writeJson(targetFile, originalData);

      expect(targetFile.existsSync(), isTrue);
      expect(jsonDecode(targetFile.readAsStringSync(encoding: utf8))['title'], 'Versi Asli');

      // Inject failure right before rename
      AtomicFileWriter.failBeforeRename = true;

      final newData = {'id': 'orig_1', 'title': 'Versi Rusak', 'content': 'Harus gagal'};
      expect(
        () async => await AtomicFileWriter.writeJson(targetFile, newData),
        throwsA(isA<FileSystemException>()),
      );

      // Verify original file is 100% intact
      expect(targetFile.existsSync(), isTrue);
      final currentData = jsonDecode(targetFile.readAsStringSync(encoding: utf8));
      expect(currentData['title'], 'Versi Asli');
      expect(currentData['content'], 'Utuh');

      // Verify no temporary files remain
      final tmps = tempDir
          .listSync()
          .where((e) => e.path.endsWith('.tmp'))
          .toList();
      expect(tmps, isEmpty);
    });

    test('tmp yatim + target hilang -> dipulihkan; tmp yatim + target ada -> tmp dibersihkan', () async {
      // Skenario A: Tmp yatim + target HILANG -> dipulihkan jadi target
      final targetA = File(p.join(tempDir.path, 'note_a.json'));
      final tmpA = File(p.join(tempDir.path, 'note_a.json.orphan123.tmp'));
      final validJsonA = {'id': 'a1', 'title': 'Catatan Terselamatkan', 'schemaVersion': 1};
      tmpA.writeAsStringSync('${jsonEncode(validJsonA)}\n', encoding: utf8, flush: true);

      expect(targetA.existsSync(), isFalse);
      expect(tmpA.existsSync(), isTrue);

      // Skenario B: Tmp yatim + target ADA -> tmp dibersihkan, target tetap utuh
      final targetB = File(p.join(tempDir.path, 'note_b.json'));
      final targetJsonB = {'id': 'b1', 'title': 'Target Eksis', 'schemaVersion': 1};
      targetB.writeAsStringSync('${jsonEncode(targetJsonB)}\n', encoding: utf8, flush: true);

      final tmpB = File(p.join(tempDir.path, 'note_b.json.orphan456.tmp'));
      final tmpJsonB = {'id': 'b1', 'title': 'Tmp Kadaluarsa', 'schemaVersion': 1};
      tmpB.writeAsStringSync('${jsonEncode(tmpJsonB)}\n', encoding: utf8, flush: true);

      expect(targetB.existsSync(), isTrue);
      expect(tmpB.existsSync(), isTrue);

      // Jalankan pemulihan
      await AtomicFileWriter.recoverOrphanTmpFiles(tempDir);

      // Verifikasi Skenario A: targetA dipulihkan dari tmpA
      expect(targetA.existsSync(), isTrue);
      final restoredA = jsonDecode(targetA.readAsStringSync(encoding: utf8));
      expect(restoredA['title'], 'Catatan Terselamatkan');
      expect(tmpA.existsSync(), isFalse);

      // Verifikasi Skenario B: targetB utuh, tmpB dihapus
      expect(targetB.existsSync(), isTrue);
      final keptB = jsonDecode(targetB.readAsStringSync(encoding: utf8));
      expect(keptB['title'], 'Target Eksis');
      expect(tmpB.existsSync(), isFalse);
    });

    test('dua penulisan beruntun ke path yang sama -> serial dan hasil akhir = yang terakhir; nama tmp tidak bentrok', () async {
      final targetFile = File(p.join(tempDir.path, 'concurrent_note.json'));

      // Luncurkan dua penulisan secara bersamaan (tidak await yang pertama dulu)
      final write1 = AtomicFileWriter.writeJson(targetFile, {
        'id': 'c1',
        'sequence': 1,
        'title': 'Penulisan Pertama',
      });
      final write2 = AtomicFileWriter.writeJson(targetFile, {
        'id': 'c1',
        'sequence': 2,
        'title': 'Penulisan Kedua (Final)',
      });

      await Future.wait([write1, write2]);

      expect(targetFile.existsSync(), isTrue);
      final finalContent = jsonDecode(targetFile.readAsStringSync(encoding: utf8));
      expect(finalContent['sequence'], 2);
      expect(finalContent['title'], 'Penulisan Kedua (Final)');

      // Tidak boleh ada file .tmp sisa
      final tmps = tempDir.listSync().where((e) => e.path.endsWith('.tmp')).toList();
      expect(tmps, isEmpty);
    });
  });

  group('Tabrakan Nama Saat Pindah / moveEntry (PRD 7.8, T1, R1)', () {
    test('pindah file ke folder yang berisi file bernama sama (termasuk beda huruf besar/kecil) -> keduanya utuh, yang dipindah ber-suffix " (2)", isi dan metadata kedua file benar', () async {
      await dataSource.createFolder(parentRelativePath: '', name: 'FolderA');
      await dataSource.createFolder(parentRelativePath: '', name: 'FolderB');

      // Buat file di FolderA
      final fileInA = PageFile(
        id: 'file_a',
        schemaVersion: 1,
        title: 'Laporan Keuangan',
        relativePath: 'FolderA/Laporan Keuangan.json',
        colorIndex: 1,
        favoritedAt: null,
        content: const [
          {'insert': 'Isi Folder A\n'}
        ],
        plainText: 'Isi Folder A',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final savedA = await dataSource.writePage(fileInA, targetFolderRelativePath: 'FolderA');

      // Buat file di FolderB dengan nama yang sama tapi beda case: 'laporan keuangan.json'
      final fileInB = PageFile(
        id: 'file_b',
        schemaVersion: 1,
        title: 'laporan keuangan',
        relativePath: 'FolderB/laporan keuangan.json',
        colorIndex: 2,
        favoritedAt: null,
        content: const [
          {'insert': 'Isi Folder B\n'}
        ],
        plainText: 'Isi Folder B',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await dataSource.writePage(fileInB, targetFolderRelativePath: 'FolderB');

      // Pindahkan savedA dari FolderA ke FolderB
      final movedNode = await dataSource.moveEntry(
        entry: savedA,
        destinationFolderRelativePath: 'FolderB',
      );

      // Verifikasi kembalian: relativePath ber-suffix " (2)"
      expect(movedNode.relativePath, 'FolderB/Laporan Keuangan (2).json');

      // Verifikasi kedua file di FolderB eksis dan utuh di disk
      final existingInB = File(p.join(tempDir.path, 'FolderB', 'laporan keuangan.json'));
      final movedInB = File(p.join(tempDir.path, 'FolderB', 'Laporan Keuangan (2).json'));
      final originalA = File(p.join(tempDir.path, 'FolderA', 'Laporan Keuangan.json'));

      expect(existingInB.existsSync(), isTrue, reason: 'File tujuan lama dilarang terhapus');
      expect(movedInB.existsSync(), isTrue, reason: 'File hasil pindah harus dibuat dengan suffix');
      expect(originalA.existsSync(), isFalse, reason: 'File di folder asal harus sudah dipindah');

      // Verifikasi isi masing-masing file
      final readB = await dataSource.readPage('FolderB/laporan keuangan.json');
      expect(readB.plainText, 'Isi Folder B');
      expect(readB.id, 'file_b');

      final readMoved = await dataSource.readPage('FolderB/Laporan Keuangan (2).json');
      expect(readMoved.plainText, 'Isi Folder A');
      expect(readMoved.id, 'file_a');
      expect(readMoved.relativePath, 'FolderB/Laporan Keuangan (2).json');
    });

    test('pindah folder ke folder berisi folder bernama sama -> keduanya utuh', () async {
      await dataSource.createFolder(parentRelativePath: '', name: 'DestDir');
      final folderProyek = await dataSource.createFolder(parentRelativePath: '', name: 'Proyek');
      await dataSource.createFolder(parentRelativePath: 'DestDir', name: 'proyek');

      // Masukkan file anak ke dalam Proyek asal
      final child1 = PageFile(
        id: 'child_1',
        schemaVersion: 1,
        title: 'Anak 1',
        relativePath: 'Proyek/Anak 1.json',
        colorIndex: 0,
        favoritedAt: null,
        content: const [{'insert': 'Anak 1\n'}],
        plainText: 'Anak 1',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await dataSource.writePage(child1, targetFolderRelativePath: 'Proyek');

      // Masukkan file anak ke dalam DestDir/proyek
      final child2 = PageFile(
        id: 'child_2',
        schemaVersion: 1,
        title: 'Anak 2',
        relativePath: 'DestDir/proyek/Anak 2.json',
        colorIndex: 0,
        favoritedAt: null,
        content: const [{'insert': 'Anak 2\n'}],
        plainText: 'Anak 2',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await dataSource.writePage(child2, targetFolderRelativePath: 'DestDir/proyek');

      // Pindahkan folder Proyek ke dalam DestDir
      final movedFolder = await dataSource.moveEntry(
        entry: folderProyek,
        destinationFolderRelativePath: 'DestDir',
      );

      expect(movedFolder.relativePath, 'DestDir/Proyek (2)');

      // Periksa kedua folder dan isinya utuh
      final dir1 = Directory(p.join(tempDir.path, 'DestDir', 'proyek'));
      final dir2 = Directory(p.join(tempDir.path, 'DestDir', 'Proyek (2)'));
      expect(dir1.existsSync(), isTrue);
      expect(dir2.existsSync(), isTrue);

      final fileChild1 = File(p.join(tempDir.path, 'DestDir', 'Proyek (2)', 'Anak 1.json'));
      final fileChild2 = File(p.join(tempDir.path, 'DestDir', 'proyek', 'Anak 2.json'));
      expect(fileChild1.existsSync(), isTrue);
      expect(fileChild2.existsSync(), isTrue);
    });

    test('pindah ke folder yang sama -> tidak berubah', () async {
      await dataSource.createFolder(parentRelativePath: '', name: 'FolderTetap');
      final file = PageFile(
        id: 'page_same',
        schemaVersion: 1,
        title: 'Tetap Di Sini',
        relativePath: 'FolderTetap/Tetap Di Sini.json',
        colorIndex: 0,
        favoritedAt: null,
        content: const [{'insert': 'Tetap\n'}],
        plainText: 'Tetap',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final saved = await dataSource.writePage(file, targetFolderRelativePath: 'FolderTetap');

      final result = await dataSource.moveEntry(
        entry: saved,
        destinationFolderRelativePath: 'FolderTetap',
      );

      expect(result.relativePath, 'FolderTetap/Tetap Di Sini.json');
      final f = File(p.join(tempDir.path, 'FolderTetap', 'Tetap Di Sini.json'));
      expect(f.existsSync(), isTrue);
      expect(f.readAsStringSync(encoding: utf8), contains('Tetap Di Sini'));
    });
  });
}
