import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/migration/migration_runner.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MigrationRunner (PRD 6.7)', () {
    test('migrates forward sequentially from v1 to v3 in-memory and in directory', () async {
      final file = File('${tempDir.path}/note.json');
      await file.writeAsString(jsonEncode({
        'id': 'note_1',
        'schemaVersion': 1,
        'title': 'Original',
        'customField': 'keepMe',
      }));

      final runner = MigrationRunner(
        targetVersion: 3,
        migrations: {
          1: (data) {
            data['v2Field'] = 'migrated_to_2';
            return data;
          },
          2: (data) {
            data['v3Field'] = 'migrated_to_3';
            return data;
          },
        },
      );

      // In-memory test
      final inMemoryResult = runner.migrateJson({
        'id': 'note_mem',
        'schemaVersion': 1,
        'title': 'Memory',
      });
      expect(inMemoryResult['schemaVersion'], 3);
      expect(inMemoryResult['v2Field'], 'migrated_to_2');
      expect(inMemoryResult['v3Field'], 'migrated_to_3');

      // Directory test
      await runner.migrateDirectory(tempDir);

      final onDisk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(onDisk['schemaVersion'], 3);
      expect(onDisk['title'], 'Original');
      expect(onDisk['customField'], 'keepMe');
      expect(onDisk['v2Field'], 'migrated_to_2');
      expect(onDisk['v3Field'], 'migrated_to_3');

      // Verify backup file was removed after success
      final bakFile = File('${file.path}.bak');
      expect(await bakFile.exists(), isFalse);
    });

    test('rolls back to original file when a migration step fails', () async {
      final file = File('${tempDir.path}/failing_note.json');
      final originalMap = {
        'id': 'note_fail',
        'schemaVersion': 1,
        'importantData': 'precious',
      };
      await file.writeAsString(jsonEncode(originalMap));

      final runner = MigrationRunner(
        targetVersion: 3,
        migrations: {
          1: (data) {
            data['step1'] = 'ok';
            return data;
          },
          2: (data) {
            throw Exception('Disk error or crash during step 2->3');
          },
        },
      );

      expect(
        () => runner.migrateDirectory(tempDir),
        throwsA(isA<MigrationFailedException>()),
      );

      // Verify file is restored to original content
      final contentAfterFailure = await file.readAsString();
      final decodedAfterFailure = jsonDecode(contentAfterFailure) as Map<String, dynamic>;
      expect(decodedAfterFailure['schemaVersion'], 1);
      expect(decodedAfterFailure['importantData'], 'precious');
      expect(decodedAfterFailure.containsKey('step1'), isFalse);

      // Verify .bak file is cleaned up after rollback
      final bakFile = File('${file.path}.bak');
      expect(await bakFile.exists(), isFalse);
    });

    test('preserves unrecognized unknown fields across migrations', () async {
      final file = File('${tempDir.path}/unknown_fields.json');
      await file.writeAsString(jsonEncode({
        'id': 'note_ext',
        'schemaVersion': 1,
        'title': 'My Title',
        'plugin_sync_hash': 'abc-123-xyz',
        'future_feature_flag': true,
        'nested_object': {'k1': 'v1', 'count': 42},
      }));

      final runner = MigrationRunner(
        targetVersion: 2,
        migrations: {
          1: (data) {
            data['migrated'] = true;
            return data;
          },
        },
      );

      await runner.migrateDirectory(tempDir);

      final onDisk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(onDisk['schemaVersion'], 2);
      expect(onDisk['migrated'], isTrue);
      expect(onDisk['plugin_sync_hash'], 'abc-123-xyz');
      expect(onDisk['future_feature_flag'], isTrue);
      expect(onDisk['nested_object']['k1'], 'v1');
      expect(onDisk['nested_object']['count'], 42);
    });

    test('throws NewerSchemaVersionException when schemaVersion is newer than supported', () async {
      final runner = MigrationRunner(
        targetVersion: 1,
        migrations: {},
      );

      // In-memory test
      expect(
        () => runner.migrateJson({
          'id': 'future_note',
          'schemaVersion': 99,
          'title': 'From Year 2030',
        }),
        throwsA(isA<NewerSchemaVersionException>()),
      );

      // In directory: files with schemaVersion > targetVersion remain untouched (read-only)
      final file = File('${tempDir.path}/newer_version.json');
      final originalFutureJson = jsonEncode({
        'id': 'future_note',
        'schemaVersion': 99,
        'title': 'From Year 2030',
      });
      await file.writeAsString(originalFutureJson);

      await runner.migrateDirectory(tempDir);

      final onDisk = await file.readAsString();
      expect(jsonDecode(onDisk)['schemaVersion'], 99);
      expect(jsonDecode(onDisk)['title'], 'From Year 2030');
    });
  });
}
