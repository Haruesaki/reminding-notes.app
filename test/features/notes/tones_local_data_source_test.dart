import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/features/notes/data/datasources/tones_local_data_source.dart';
import 'package:reminding/features/notes/data/services/media_store_service.dart';

class FakeMediaStoreService extends MediaStoreService {
  final List<String> registered = [];
  final List<String> deleted = [];

  @override
  Future<String?> registerToneToMediaStore({
    required String filePath,
    required String title,
  }) async {
    final uri = 'content://media/external/audio/media/${registered.length + 1}';
    registered.add(uri);
    return uri;
  }

  @override
  Future<bool> deleteToneFromMediaStore(String contentUri) async {
    deleted.add(contentUri);
    return true;
  }

  @override
  Future<bool> deleteNotificationChannel(String channelId) async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempAssetsDir;
  late Directory tempNotesDir;
  late FakeMediaStoreService fakeMediaStore;
  late TonesLocalDataSource dataSource;

  setUp(() async {
    final base = await Directory.systemTemp.createTemp('tones_test_');
    tempAssetsDir = Directory('${base.path}/notes_assets');
    tempNotesDir = Directory('${base.path}/notes_data');
    tempAssetsDir.createSync(recursive: true);
    tempNotesDir.createSync(recursive: true);

    fakeMediaStore = FakeMediaStoreService();
    dataSource = TonesLocalDataSource(
      assetsDir: tempAssetsDir,
      notesDir: tempNotesDir,
      mediaStoreService: fakeMediaStore,
    );
  });

  tearDown(() async {
    if (tempAssetsDir.existsSync()) {
      tempAssetsDir.deleteSync(recursive: true);
    }
    if (tempNotesDir.existsSync()) {
      tempNotesDir.deleteSync(recursive: true);
    }
  });

  group('TonesLocalDataSource (PRD 8.3 & 7.6)', () {
    test('init() creates tones/ directory and initial tones.json', () async {
      await dataSource.init();

      expect(dataSource.tonesDir.existsSync(), isTrue);
      expect(dataSource.tonesMetaFile.existsSync(), isTrue);

      final json = jsonDecode(await dataSource.tonesMetaFile.readAsString()) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect(json['tones'], isEmpty);
    });

    test('addTone() saves tone file and registers to MediaStore', () async {
      final sampleAudio = File('${tempAssetsDir.path}/sample.mp3');
      await sampleAudio.writeAsBytes(List.filled(1024, 0)); // 1 KB sample

      final tone = await dataSource.addTone(
        sourceFile: sampleAudio,
        name: 'Bel Sekolah',
      );

      expect(tone.name, 'Bel Sekolah');
      expect(tone.contentUri, startsWith('content://media/'));

      final list = await dataSource.getTones();
      expect(list.length, 1);
      expect(list.first.id, tone.id);
      expect(File('${tempAssetsDir.path}/${tone.relativePath}').existsSync(), isTrue);
    });

    test('addTone() throws ToneFileSizeLimitException if file exceeds 10 MB', () async {
      final largeFile = File('${tempAssetsDir.path}/huge.mp3');
      // Create a 10.5 MB file
      final size = (10.5 * 1024 * 1024).toInt();
      final raf = await largeFile.open(mode: FileMode.write);
      await raf.truncate(size);
      await raf.close();

      expect(
        () => dataSource.addTone(sourceFile: largeFile, name: 'Huge Tone'),
        throwsA(isA<ToneFileSizeLimitException>()),
      );
    });

    test('deleteTone() removes audio file, meta, and cascades reset on tasks in notesDir', () async {
      // 1. Add tone
      final sampleAudio = File('${tempAssetsDir.path}/chime.mp3');
      await sampleAudio.writeAsBytes(List.filled(512, 0));
      final tone = await dataSource.addTone(sourceFile: sampleAudio, name: 'Chime');

      // 2. Create a list file in notesDir referencing this tone
      final listFile = File('${tempNotesDir.path}/shopping.json');
      await listFile.writeAsString(jsonEncode({
        'id': 'list_123',
        'type': 'list',
        'schemaVersion': 1,
        'title': 'Belanja',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'tasks': [
          {
            'id': 'task_1',
            'text': 'Beli Apel',
            'done': false,
            'deadline': {
              'at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
              'notificationToneId': tone.id,
              'reminderDaysBefore': 2,
              'reminderTimes': ['09:00'],
            },
            'alarm': {
              'at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
              'enabled': true,
              'toneId': tone.id,
            },
            'subtasks': [],
          }
        ],
      }));

      // Count affected tasks
      final affectedCount = await dataSource.countAffectedTasks(tone.id);
      expect(affectedCount, 1);

      // 3. Delete tone
      await dataSource.deleteTone(tone.id);

      // Verify tone is removed from list
      final tonesAfter = await dataSource.getTones();
      expect(tonesAfter.any((t) => t.id == tone.id), isFalse);
      expect(fakeMediaStore.deleted.contains(tone.contentUri), isTrue);

      // Verify task in shopping.json had toneId reset to null (PRD 8.3)
      final content = jsonDecode(await listFile.readAsString()) as Map<String, dynamic>;
      final tasks = content['tasks'] as List<dynamic>;
      final task = tasks[0] as Map<String, dynamic>;
      expect(task['deadline']['notificationToneId'], isNull);
      expect(task['alarm']['toneId'], isNull);
    });
  });
}
