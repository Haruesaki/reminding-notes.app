import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/core/migration/migration_runner.dart';
import 'package:reminding/features/backup/data/services/backup_service.dart';
import 'package:reminding/features/backup/domain/models/backup_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late Directory notesDir;
  late Directory assetsDir;
  late BackupService backupService;

  setUp(() async {
    tempBaseDir = await Directory.systemTemp.createTemp('backup_test_');
    notesDir = Directory(p.join(tempBaseDir.path, 'notes_data'))..createSync(recursive: true);
    assetsDir = Directory(p.join(tempBaseDir.path, 'assets'))..createSync(recursive: true);
    backupService = BackupService();
  });

  tearDown(() {
    if (tempBaseDir.existsSync()) {
      try {
        tempBaseDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Map<String, String> computeDirectoryHashes(Directory dir) {
    final hashes = <String, String>{};
    if (!dir.existsSync()) return hashes;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        final relPath = p.relative(entity.path, from: dir.path).replaceAll('\\', '/');
        final bytes = entity.readAsBytesSync();
        hashes[relPath] = sha256.convert(bytes).toString();
      }
    }
    return hashes;
  }

  test('WAJIB Round-trip: export -> hapus data -> import -> pohon direktori dan hash isi identik', () async {
    // 1. Siapkan struktur awal notes_data/
    // Root folder metadata
    final rootMeta = File(p.join(notesDir.path, '_folder.json'));
    rootMeta.writeAsStringSync(jsonEncode({
      'version': MigrationRunner.currentSchemaVersion,
      'createdAt': '2026-11-01T10:00:00.000Z',
      'order': ['note-1.json', 'folder-kerja', 'list-1.json'],
    }));

    // File note-1.json
    final noteFile = File(p.join(notesDir.path, 'note-1.json'));
    noteFile.writeAsStringSync(jsonEncode({
      'id': 'note-1',
      'title': 'Catatan Penting',
      'type': 'page',
      'content': 'Ini adalah isi catatan rahasia',
      'createdAt': '2026-11-01T10:05:00.000Z',
      'updatedAt': '2026-11-01T10:10:00.000Z',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    // Subfolder folder-kerja
    final subFolder = Directory(p.join(notesDir.path, 'folder-kerja'))..createSync();
    final subMeta = File(p.join(subFolder.path, '_folder.json'));
    subMeta.writeAsStringSync(jsonEncode({
      'version': MigrationRunner.currentSchemaVersion,
      'createdAt': '2026-11-01T10:15:00.000Z',
      'order': ['subnote.json'],
    }));

    final subNote = File(p.join(subFolder.path, 'subnote.json'));
    subNote.writeAsStringSync(jsonEncode({
      'id': 'sub-1',
      'title': 'Sub Catatan Kerja',
      'type': 'page',
      'content': 'Laporan progres mingguan',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    // File list-1.json dengan reminder
    final listFile = File(p.join(notesDir.path, 'list-1.json'));
    listFile.writeAsStringSync(jsonEncode({
      'id': 'list-1',
      'title': 'To-do Harian',
      'type': 'list',
      'items': [
        {
          'id': 'item-1',
          'text': 'Kerjakan M9',
          'isDone': false,
          'deadline': '2026-11-10T09:00:00.000Z',
          'remindBeforeMinutes': [10],
          'reminderTone': 'tones/bell.mp3',
        }
      ],
      'version': MigrationRunner.currentSchemaVersion,
    }));

    // Siapkan assets (tones.json dan nada)
    final tonesJson = File(p.join(assetsDir.path, 'tones.json'));
    tonesJson.writeAsStringSync(jsonEncode([
      {
        'id': 'tone-1',
        'title': 'Bell Custom',
        'fileName': 'bell.mp3',
        'filePath': 'tones/bell.mp3',
        'isCustom': true,
      }
    ]));

    final tonesSubdir = Directory(p.join(assetsDir.path, 'tones'))..createSync();
    final toneAudio = File(p.join(tonesSubdir.path, 'bell.mp3'));
    toneAudio.writeAsBytesSync(Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00]));

    // Hitung hash sebelum export
    final originalNotesHashes = computeDirectoryHashes(notesDir);
    final originalAssetsHashes = computeDirectoryHashes(assetsDir);
    expect(originalNotesHashes.isNotEmpty, isTrue);
    expect(originalAssetsHashes.isNotEmpty, isTrue);

    // 2. Export ke ZIP
    final zipBytes = await backupService.createBackup(
      notesDir: notesDir,
      assetsDir: assetsDir,
    );
    expect(zipBytes, isNotEmpty);

    // 3. Hapus seluruh data yang ada
    notesDir.deleteSync(recursive: true);
    assetsDir.deleteSync(recursive: true);
    notesDir.createSync(recursive: true);
    assetsDir.createSync(recursive: true);
    expect(computeDirectoryHashes(notesDir).isEmpty, isTrue);
    expect(computeDirectoryHashes(assetsDir).isEmpty, isTrue);

    // 4. Inspect Backup
    final tempExtractDir = Directory(p.join(tempBaseDir.path, 'inspect_roundtrip'));
    final inspection = await backupService.inspectBackup(
      zipBytes: zipBytes,
      tempExtractDir: tempExtractDir,
    );
    expect(inspection.manifest.app, equals('reminding'));
    expect(inspection.manifest.counts['notes'], equals(3)); // note-1, subnote, list-1
    expect(inspection.manifest.counts['folders'], equals(1)); // folder-kerja
    expect(inspection.manifest.counts['tones'], equals(1)); // tone-1

    // 5. Execute Replace All (Restore)
    final tempSafetyDir = Directory(p.join(tempBaseDir.path, 'safety_roundtrip'));
    await backupService.executeReplaceAll(
      extractDir: tempExtractDir,
      notesDir: notesDir,
      assetsDir: assetsDir,
      tempSafetyDir: tempSafetyDir,
    );

    // 6. Verifikasi pohon direktori dan hash isi identik
    final restoredNotesHashes = computeDirectoryHashes(notesDir);
    final restoredAssetsHashes = computeDirectoryHashes(assetsDir);

    expect(restoredNotesHashes, equals(originalNotesHashes));
    expect(restoredAssetsHashes, equals(originalAssetsHashes));
  });

  test('Tolak ZIP korup dengan InvalidBackupException', () async {
    final corruptedZipBytes = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    final tempExtractDir = Directory(p.join(tempBaseDir.path, 'corrupt_test'));

    expect(
      () => backupService.inspectBackup(
        zipBytes: corruptedZipBytes,
        tempExtractDir: tempExtractDir,
      ),
      throwsA(isA<InvalidBackupException>()),
    );
  });

  test('Tolak file jika checksum SHA-256 salah / isi file diubah (CorruptedBackupException)', () async {
    // Siapkan note
    final noteFile = File(p.join(notesDir.path, 'sample.json'));
    noteFile.writeAsStringSync(jsonEncode({
      'id': 's1',
      'title': 'Asli',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    final zipBytes = await backupService.createBackup(
      notesDir: notesDir,
      assetsDir: assetsDir,
    );

    // Decode zip dan modifikasi isi file sample.json tanpa mengubah manifest
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final tamperedArchive = Archive();

    for (final file in archive.files) {
      if (file.name == 'data/sample.json') {
        final tamperedBytes = utf8.encode(jsonEncode({
          'id': 's1',
          'title': 'Telah Dimanipulasi!',
          'version': MigrationRunner.currentSchemaVersion,
        }));
        tamperedArchive.addFile(ArchiveFile(file.name, tamperedBytes.length, tamperedBytes));
      } else {
        tamperedArchive.addFile(file);
      }
    }

    final tamperedZipBytes = Uint8List.fromList(ZipEncoder().encode(tamperedArchive));
    final tempExtractDir = Directory(p.join(tempBaseDir.path, 'tampered_test'));

    expect(
      () => backupService.inspectBackup(
        zipBytes: tamperedZipBytes,
        tempExtractDir: tempExtractDir,
      ),
      throwsA(predicate((e) =>
          e is CorruptedBackupException &&
          e.corruptedFiles.any((f) => f.contains('sample.json')))),
    );
  });

  test('Tolak ZIP yang memuat path berbahaya / Zip Slip (DangerousPathException)', () async {
    final evilArchive = Archive();

    // Tambahkan manifest minimal
    final manifestBytes = utf8.encode(jsonEncode({
      'app': 'reminding',
      'backupFormat': 1,
      'schemaVersion': MigrationRunner.currentSchemaVersion,
      'appVersion': '1.0.0',
      'createdAt': DateTime.now().toIso8601String(),
      'counts': {'notes': 0, 'folders': 0, 'tones': 0},
      'files': [
        {'path': '../evil.txt', 'sha256': 'dummy'},
      ],
    }));
    evilArchive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // Tambahkan file traversal
    final evilContent = utf8.encode('malicious payload');
    evilArchive.addFile(ArchiveFile('../evil.txt', evilContent.length, evilContent));

    final evilZipBytes = Uint8List.fromList(ZipEncoder().encode(evilArchive));
    final tempExtractDir = Directory(p.join(tempBaseDir.path, 'evil_test'));

    expect(
      () => backupService.inspectBackup(
        zipBytes: evilZipBytes,
        tempExtractDir: tempExtractDir,
      ),
      throwsA(isA<DangerousPathException>()),
    );
  });

  test('Tolak schemaVersion lebih baru (NewerSchemaVersionException)', () async {
    final futureArchive = Archive();

    final manifestBytes = utf8.encode(jsonEncode({
      'app': 'reminding',
      'backupFormat': 1,
      'schemaVersion': 999, // Versi masa depan
      'appVersion': '99.0.0',
      'createdAt': DateTime.now().toIso8601String(),
      'counts': {'notes': 0, 'folders': 0, 'tones': 0},
      'files': [],
    }));
    futureArchive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final futureZipBytes = Uint8List.fromList(ZipEncoder().encode(futureArchive));
    final tempExtractDir = Directory(p.join(tempBaseDir.path, 'future_test'));

    expect(
      () => backupService.inspectBackup(
        zipBytes: futureZipBytes,
        tempExtractDir: tempExtractDir,
      ),
      throwsA(predicate((e) =>
          e is NewerSchemaVersionException &&
          e.fileVersion == 999 &&
          e.supportedVersion == MigrationRunner.currentSchemaVersion)),
    );
  });

  test('Merge mode: entitas bertabrakan diberi akhiran " (Impor)" dan metadata digabung', () async {
    // 1. Catatan lokal yang sudah ada
    final existingNote = File(p.join(notesDir.path, 'Catatan Harian.json'));
    existingNote.writeAsStringSync(jsonEncode({
      'id': 'n-local',
      'title': 'Catatan Harian',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    final rootMeta = File(p.join(notesDir.path, '_folder.json'));
    rootMeta.writeAsStringSync(jsonEncode({
      'version': MigrationRunner.currentSchemaVersion,
      'createdAt': '2026-11-01T10:00:00.000Z',
      'order': ['Catatan Harian.json'],
    }));

    // 2. Data di backup yang punya file bernama sama "Catatan Harian.json" dan satu file unik "Baru.json"
    final backupDir = Directory(p.join(tempBaseDir.path, 'src_backup'))..createSync();
    final backupNotes = Directory(p.join(backupDir.path, 'data'))..createSync();
    Directory(p.join(backupDir.path, 'assets')).createSync();

    final importedNote = File(p.join(backupNotes.path, 'Catatan Harian.json'));
    importedNote.writeAsStringSync(jsonEncode({
      'id': 'n-imported',
      'title': 'Catatan Harian',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    final uniqueNote = File(p.join(backupNotes.path, 'Baru.json'));
    uniqueNote.writeAsStringSync(jsonEncode({
      'id': 'n-unique',
      'title': 'Baru',
      'version': MigrationRunner.currentSchemaVersion,
    }));

    final backupMeta = File(p.join(backupNotes.path, '_folder.json'));
    backupMeta.writeAsStringSync(jsonEncode({
      'version': MigrationRunner.currentSchemaVersion,
      'createdAt': '2026-11-01T10:00:00.000Z',
      'order': ['Catatan Harian.json', 'Baru.json'],
    }));

    // 3. Eksekusi merge
    await backupService.executeMerge(
      extractDir: backupDir,
      notesDir: notesDir,
      assetsDir: assetsDir,
    );

    // 4. Verifikasi: Catatan Harian asli tetap ada, Catatan Harian (Impor).json terbuat
    expect(existingNote.existsSync(), isTrue);
    final importedCollisionFile = File(p.join(notesDir.path, 'Catatan Harian (Impor).json'));
    expect(importedCollisionFile.existsSync(), isTrue);
    final importedCollisionJson = jsonDecode(importedCollisionFile.readAsStringSync());
    expect(importedCollisionJson['title'], equals('Catatan Harian (Impor)'));

    final uniqueFile = File(p.join(notesDir.path, 'Baru.json'));
    expect(uniqueFile.existsSync(), isTrue);
    final uniqueJson = jsonDecode(uniqueFile.readAsStringSync());
    expect(uniqueJson['id'], equals('n-unique'));

    // Verifikasi urutan di _folder.json telah memuat keduanya
    final updatedMetaJson = jsonDecode(rootMeta.readAsStringSync());
    final orderList = List<String>.from(updatedMetaJson['order']);
    expect(orderList, contains(importedCollisionJson['id']));
    expect(orderList, contains('n-unique'));
  });
}
