import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:reminding/app.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/core/error/failures.dart';
import 'package:reminding/core/migration/data_access_mode.dart';
import 'package:reminding/core/migration/migration_runner.dart';
import 'package:reminding/core/router/app_router.dart';
import 'package:reminding/features/backup/data/services/backup_service.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'package:reminding/features/notes/data/datasources/tones_local_data_source.dart';
import 'package:reminding/features/notes/data/services/notification_plugin_client.dart';
import 'package:reminding/features/notes/domain/services/reminder_calculator.dart';
import 'package:reminding/features/notes/domain/services/reminder_sync_service.dart';
import 'package:reminding/features/notes/presentation/bloc/list_editor/list_editor_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/list_editor/list_editor_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_editor/note_editor_event.dart';
import 'package:reminding/features/notes/presentation/bloc/tones/tones_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/tones/tones_event.dart';
import 'package:timezone/timezone.dart' as tz;

class _FakeAudioPlayer extends Fake implements AudioPlayer {
  @override
  Stream<void> get onPlayerComplete => const Stream<void>.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class FakeScheduledRecord {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails notificationDetails;
  final AndroidScheduleMode androidScheduleMode;
  final String? payload;

  FakeScheduledRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.notificationDetails,
    required this.androidScheduleMode,
    required this.payload,
  });
}

class FakeNotificationPluginClient implements NotificationPluginClient {
  final Map<int, FakeScheduledRecord> scheduled = {};
  final List<int> cancelledIds = [];
  int cancelAllCount = 0;
  int zonedScheduleCalls = 0;
  String? launchPayload;
  void Function(NotificationResponse)? _onResponse;

  void seedPending({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) {
    scheduled[id] = FakeScheduledRecord(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(const Duration(days: 1)),
        tz.UTC,
      ),
      notificationDetails: const NotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  void simulateTap(String payload) {
    _onResponse?.call(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> initialize({
    required InitializationSettings settings,
    required void Function(NotificationResponse response)
        onDidReceiveNotificationResponse,
  }) async {
    _onResponse = onDidReceiveNotificationResponse;
  }

  @override
  Future<String?> getLaunchNotificationPayload() async => launchPayload;

  @override
  Future<void> createAndroidNotificationChannel(
    AndroidNotificationChannel channel,
  ) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) async {
    zonedScheduleCalls++;
    scheduled[id] = FakeScheduledRecord(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: androidScheduleMode,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduled.values
        .map(
          (r) => PendingNotificationRequest(r.id, r.title, r.body, r.payload),
        )
        .toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandboxDir;
  late Directory notesDir;
  late Directory assetsDir;
  late Directory supportDir;
  late FakeNotificationPluginClient fakePlugin;
  late String currentTimezone;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() async {
    sandboxDir = await Directory.systemTemp.createTemp('r2_test_');
    notesDir = Directory(p.join(sandboxDir.path, 'notes_data'))
      ..createSync(recursive: true);
    assetsDir = Directory(p.join(sandboxDir.path, 'notes_assets'))
      ..createSync(recursive: true);
    supportDir = Directory(p.join(sandboxDir.path, 'support'))
      ..createSync(recursive: true);
    fakePlugin = FakeNotificationPluginClient();
    currentTimezone = 'Asia/Jakarta';
  });

  tearDown(() async {
    await sl.reset();
    if (sandboxDir.existsSync()) {
      try {
        sandboxDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  ListFile buildListWithDeadline({
    required String id,
    required String relativePath,
    required String title,
    required String taskId,
    String taskText = 'Tugas Penting',
    bool done = false,
    DateTime? deadlineAt,
    String? toneId,
  }) {
    final now = DateTime.now();
    return ListFile(
      id: id,
      relativePath: relativePath,
      title: title,
      colorIndex: 0,
      favoritedAt: null,
      createdAt: now,
      updatedAt: now,
      tasks: [
        Task(
          id: taskId,
          text: taskText,
          done: done,
          deadline: DeadlineSettings(
            at: deadlineAt ?? now.add(const Duration(days: 4)),
            remindStartDaysBefore: 2,
            remindTimes: const ['09:00', '15:00'],
            notificationToneId: toneId,
          ),
        ),
      ],
    );
  }

  group('R2 - Rekonsiliasi, Zona Waktu & Siklus Hidup Notifikasi', () {
    test('1 & 2. Jadwal yatim dibatalkan dan jadwal yang kurang ditambahkan secara deterministik',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
        reconcileOnStart: false,
      );

      final repo = sl<ExplorerRepository>();
      final saved = await repo.saveList(
        buildListWithDeadline(
          id: 'list_r2_1',
          relativePath: '',
          title: 'Daftar Uji',
          taskId: 'task_r2_1',
        ),
        targetFolderRelativePath: '',
      );

      // Hapus semua jadwal dari fake plugin untuk simulasi "jadwal yang kurang",
      // lalu sisipkan jadwal yatim yang tidak ada di disk.
      fakePlugin.scheduled.clear();
      fakePlugin.cancelledIds.clear();
      fakePlugin.zonedScheduleCalls = 0;

      const orphanId = 987654321;
      fakePlugin.seedPending(
        id: orphanId,
        title: 'Yatim',
        body: 'Sisa',
        payload: jsonEncode({'fileId': 'file_hilang', 'taskId': 'task_hilang'}),
      );

      final expectedSlots = ReminderCalculator.calculateReminderSlots(
        deadline: saved.tasks.first.deadline!.at,
        remindStartDaysBefore: saved.tasks.first.deadline!.remindStartDaysBefore,
        remindTimes: saved.tasks.first.deadline!.remindTimes,
        now: DateTime.now(),
      );
      expect(expectedSlots, isNotEmpty);

      await sl<ReminderSyncService>().reconcileAllReminders();

      // Jadwal yatim dibatalkan
      expect(fakePlugin.cancelledIds, contains(orphanId));
      expect(fakePlugin.scheduled.containsKey(orphanId), isFalse);

      // Semua jadwal yang kurang ditambahkan dengan ID deterministik & payload id-only
      for (final slot in expectedSlots) {
        final expectedId =
            ReminderCalculator.getNotificationId('task_r2_1', slot);
        expect(fakePlugin.scheduled.containsKey(expectedId), isTrue);
        final payload =
            jsonDecode(fakePlugin.scheduled[expectedId]!.payload!)
                as Map<String, dynamic>;
        expect(payload['fileId'], saved.id);
        expect(payload['taskId'], 'task_r2_1');
        expect(payload.containsKey('relativePath'), isFalse);
      }

      // Rekonsiliasi kedua tanpa perubahan tidak menjadwal ulang ulangan
      final callsBeforeSecond = fakePlugin.zonedScheduleCalls;
      final cancelsBeforeSecond = fakePlugin.cancelledIds.length;
      await sl<ReminderSyncService>().reconcileAllReminders();
      expect(fakePlugin.zonedScheduleCalls, callsBeforeSecond);
      expect(fakePlugin.cancelledIds.length, cancelsBeforeSecond);
    });

    test('3. Perubahan zona waktu disimpan di direktori support dan memicu jadwal ulang semua notifikasi',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final repo = sl<ExplorerRepository>();
      await repo.saveList(
        buildListWithDeadline(
          id: 'list_tz_1',
          relativePath: '',
          title: 'Daftar TZ',
          taskId: 'task_tz_1',
        ),
        targetFolderRelativePath: '',
      );

      final tzFile = File(p.join(supportDir.path, 'last_timezone.txt'));
      expect(tzFile.existsSync(), isTrue);
      expect(tzFile.readAsStringSync().trim(), 'Asia/Jakarta');
      expect(
        File(p.join(notesDir.path, 'last_timezone.txt')).existsSync(),
        isFalse,
      );
      expect(fakePlugin.scheduled, isNotEmpty);
      expect(
        fakePlugin.scheduled.values.first.scheduledDate.location.name,
        'Asia/Jakarta',
      );

      final callsBefore = fakePlugin.zonedScheduleCalls;
      currentTimezone = 'Asia/Tokyo';
      await sl<ReminderSyncService>().reconcileAllReminders();

      expect(tzFile.readAsStringSync().trim(), 'Asia/Tokyo');
      expect(fakePlugin.zonedScheduleCalls, greaterThan(callsBefore));
      expect(fakePlugin.scheduled, isNotEmpty);
      expect(
        fakePlugin.scheduled.values.first.scheduledDate.location.name,
        'Asia/Tokyo',
      );
    });

    test('4. Hapus file dan hapus folder rekursif membatalkan semua jadwal terkait saja',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final repo = sl<ExplorerRepository>();
      final folderKerja = await repo.createFolder(
        name: 'Kerja',
        parentRelativePath: '',
      );
      final subFolder = await repo.createFolder(
        name: 'Sub',
        parentRelativePath: folderKerja.relativePath,
      );

      final listInSub = await repo.saveList(
        buildListWithDeadline(
          id: 'list_in_sub',
          relativePath: '',
          title: 'Tugas Sub',
          taskId: 'task_sub_1',
        ),
        targetFolderRelativePath: subFolder.relativePath,
      );
      final listAtRootDelete = await repo.saveList(
        buildListWithDeadline(
          id: 'list_root_del',
          relativePath: '',
          title: 'Hapus Aku',
          taskId: 'task_root_del',
        ),
        targetFolderRelativePath: '',
      );
      final listKeep = await repo.saveList(
        buildListWithDeadline(
          id: 'list_keep',
          relativePath: '',
          title: 'Tetap Ada',
          taskId: 'task_keep_1',
        ),
        targetFolderRelativePath: '',
      );

      bool hasFileNotifications(String fileId) {
        return fakePlugin.scheduled.values.any((r) {
          if (r.payload == null) return false;
          final map = jsonDecode(r.payload!) as Map<String, dynamic>;
          return map['fileId'] == fileId;
        });
      }

      expect(hasFileNotifications(listInSub.id), isTrue);
      expect(hasFileNotifications(listAtRootDelete.id), isTrue);
      expect(hasFileNotifications(listKeep.id), isTrue);

      // Hapus file tunggal
      await repo.deleteEntry(listAtRootDelete);
      expect(hasFileNotifications(listAtRootDelete.id), isFalse);
      expect(hasFileNotifications(listInSub.id), isTrue);
      expect(hasFileNotifications(listKeep.id), isTrue);

      // Hapus folder induk secara rekursif -> semua file di subfolder batal
      await repo.deleteEntry(folderKerja);
      expect(hasFileNotifications(listInSub.id), isFalse);
      expect(hasFileNotifications(listKeep.id), isTrue);
    });

    test('5. Salin file List menjadwalkan notifikasi untuk task hasil salinan ber-ID baru',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final repo = sl<ExplorerRepository>();
      final original = await repo.saveList(
        buildListWithDeadline(
          id: 'list_orig',
          relativePath: '',
          title: 'Asli',
          taskId: 'task_orig_1',
        ),
        targetFolderRelativePath: '',
      );

      final copied = await repo.copyFile(
        file: original,
        destinationFolderRelativePath: '',
      ) as ListFile;
      expect(copied.id, isNot(original.id));
      expect(copied.tasks.first.id, isNot(original.tasks.first.id));

      final origNotifs = fakePlugin.scheduled.values.where((r) {
        final m = jsonDecode(r.payload!) as Map<String, dynamic>;
        return m['fileId'] == original.id && m['taskId'] == original.tasks.first.id;
      }).toList();
      final copyNotifs = fakePlugin.scheduled.values.where((r) {
        final m = jsonDecode(r.payload!) as Map<String, dynamic>;
        return m['fileId'] == copied.id && m['taskId'] == copied.tasks.first.id;
      }).toList();

      expect(origNotifs, isNotEmpty);
      expect(copyNotifs, isNotEmpty);
      expect(copyNotifs.length, origNotifs.length);
    });

    test('6. Pindah dan rename tidak merusak payload dan resolusi tap menunjuk path terbaru',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final repo = sl<ExplorerRepository>();
      final folderA = await repo.createFolder(name: 'Asal', parentRelativePath: '');
      final folderB = await repo.createFolder(name: 'Tujuan', parentRelativePath: '');

      final created = await repo.saveList(
        buildListWithDeadline(
          id: 'list_move_1',
          relativePath: '',
          title: 'Checklist Pindah',
          taskId: 'task_move_1',
        ),
        targetFolderRelativePath: folderA.relativePath,
      );

      final scheduledBefore = fakePlugin.scheduled.values.first;
      final payloadStr = scheduledBefore.payload!;
      final payloadMap = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(payloadMap['fileId'], created.id);
      expect(payloadMap['taskId'], 'task_move_1');
      expect(payloadMap.containsKey('relativePath'), isFalse);

      // Pindahkan ke folder Tujuan lalu ubah nama file
      final moved = await repo.moveEntry(
        entry: created,
        destinationFolderRelativePath: folderB.relativePath,
      ) as ListFile;
      final renamed = await repo.renameFile(
        fileRelativePath: moved.relativePath,
        newTitle: 'Checklist Baru',
      ) as ListFile;

      expect(renamed.id, created.id);
      expect(p.dirname(renamed.relativePath), folderB.relativePath);

      final resolved = await sl<ReminderSyncService>().resolveNotificationPayload(
        payloadStr,
      );
      expect(resolved, isNotNull);
      expect(resolved!.fileId, created.id);
      expect(resolved.taskId, 'task_move_1');
      expect(resolved.fileEntry.relativePath, renamed.relativePath);
      expect(resolved.folderRelativePath, folderB.relativePath);
    });

    test('Mutasi task di ListEditorBloc dan hapus nada di TonesBloc menyinkronkan notifikasi',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final tonesDs = sl<TonesLocalDataSource>();
      final toneSrc = File(p.join(sandboxDir.path, 'ring.mp3'))
        ..writeAsBytesSync([1, 2, 3, 4]);
      final addedTone = await tonesDs.addTone(
        sourceFile: toneSrc,
        name: 'Nada Khusus',
      );

      final repo = sl<ExplorerRepository>();
      final list = await repo.saveList(
        buildListWithDeadline(
          id: 'list_mut_1',
          relativePath: '',
          title: 'Mutasi',
          taskId: 'task_mut_1',
          toneId: addedTone.id,
        ),
        targetFolderRelativePath: '',
      );

      expect(fakePlugin.scheduled, isNotEmpty);
      expect(
        fakePlugin.scheduled.values.first.notificationDetails.android?.channelId,
        'reminder_${addedTone.id}',
      );

      // Hapus nada via TonesBloc -> notifikasi untuk file tersebut dijadwal ulang ke channel default
      final tonesBloc = TonesBloc(
        dataSource: sl<TonesLocalDataSource>(),
        reminderSyncService: sl<ReminderSyncService>(),
        audioPlayer: _FakeAudioPlayer(),
      );
      tonesBloc.add(const LoadTones());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      tonesBloc.add(DeleteToneEvent(addedTone.id));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tonesBloc.close();

      expect(fakePlugin.scheduled, isNotEmpty);
      expect(
        fakePlugin.scheduled.values.first.notificationDetails.android?.channelId,
        'reminder_default',
      );

      // Centang selesai & buka kembali task via ListEditorBloc
      final bloc = sl<ListEditorBloc>();
      bloc.add(InitializeList(listId: list.id));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      bloc.add(const ToggleListTaskDone('task_mut_1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakePlugin.scheduled, isEmpty);

      bloc.add(const ToggleListTaskDone('task_mut_1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakePlugin.scheduled, isNotEmpty);

      // Hapus task lalu restore
      bloc.add(const DeleteListTask('task_mut_1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakePlugin.scheduled, isEmpty);

      final deletedTask = list.tasks.first.copyWith(
        deadline: list.tasks.first.deadline!.copyWith(clearNotificationToneId: true),
      );
      bloc.add(RestoreListTask(task: deletedTask, index: 0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakePlugin.scheduled, isNotEmpty);

      // Ubah deadline/jam/N via UpdateTaskSettings
      final prevIds = fakePlugin.scheduled.keys.toSet();
      final changedTask = deletedTask.copyWith(
        deadline: deletedTask.deadline!.copyWith(
          at: DateTime.now().add(const Duration(days: 6)),
          remindStartDaysBefore: 3,
          remindTimes: const ['08:00'],
        ),
      );
      bloc.add(UpdateTaskSettings(changedTask));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(fakePlugin.scheduled, isNotEmpty);
      expect(fakePlugin.scheduled.keys.toSet(), isNot(prevIds));

      await bloc.close();
    });

    test('Import backup (executeReplaceAll) membatalkan jadwal lama dan menjadwalkan dari backup',
        () async {
      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      final repo = sl<ExplorerRepository>();
      await repo.saveList(
        buildListWithDeadline(
          id: 'old_list',
          relativePath: '',
          title: 'Lama',
          taskId: 'old_task',
        ),
        targetFolderRelativePath: '',
      );
      expect(fakePlugin.scheduled, isNotEmpty);

      // Siapkan direktori ekstraksi backup berisi list baru dengan deadline
      final extractDir = Directory(p.join(sandboxDir.path, 'extracted_backup'))
        ..createSync(recursive: true);
      final extractData = Directory(p.join(extractDir.path, 'data'))
        ..createSync(recursive: true);
      final extractAssets = Directory(p.join(extractDir.path, 'assets'))
        ..createSync(recursive: true);
      final futureDeadline = DateTime.now().add(const Duration(days: 4));

      File(p.join(extractData.path, '_folder.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 1,
        'id': 'root',
        'name': 'root',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'order': ['imported_list.json'],
      }));
      File(p.join(extractData.path, 'imported_list.json')).writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'id': 'imported_list',
          'type': 'list',
          'title': 'Hasil Impor',
          'colorIndex': 0,
          'createdAt': '2026-11-01T00:00:00.000Z',
          'updatedAt': '2026-11-01T00:00:00.000Z',
          'tasks': [
            {
              'id': 'imported_task',
              'text': 'Tugas Backup',
              'done': false,
              'collapsed': false,
              'subtasks': <dynamic>[],
              'deadline': {
                'at': futureDeadline.toUtc().toIso8601String(),
                'remindStartDaysBefore': 2,
                'remindTimes': ['10:00'],
                'notificationToneId': null,
              },
            },
          ],
        }),
      );
      File(p.join(extractAssets.path, 'tones.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 1,
        'tones': <dynamic>[],
      }));

      final safetyDir = Directory(p.join(sandboxDir.path, 'safety'));
      await sl<BackupService>().executeReplaceAll(
        extractDir: extractDir,
        notesDir: notesDir,
        assetsDir: assetsDir,
        tempSafetyDir: safetyDir,
      );

      final payloads = fakePlugin.scheduled.values
          .map((r) => jsonDecode(r.payload!) as Map<String, dynamic>)
          .toList();
      expect(payloads, isNotEmpty);
      expect(payloads.any((m) => m['fileId'] == 'old_list'), isFalse);
      expect(
        payloads.every(
          (m) => m['fileId'] == 'imported_list' && m['taskId'] == 'imported_task',
        ),
        isTrue,
      );
    });
  });

  group('R2 - Migrasi saat Startup, Rollback, Read-Only, & Idempotensi', () {
    test('7a & 7d. Migrasi v0 ke v1 berjalan sebelum init() datasource dan idempoten saat dijalankan dua kali',
        () async {
      // Siapkan data v0 di notes_data dan notes_assets/tones.json
      File(p.join(notesDir.path, '_folder.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 0,
        'id': 'root',
        'name': 'root',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'order': ['list_v0.json'],
      }));
      File(p.join(notesDir.path, 'list_v0.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 0,
        'id': 'list_v0',
        'type': 'list',
        'title': 'List Lama',
        'colorIndex': 0,
        'createdAt': '2026-11-01T00:00:00.000Z',
        'updatedAt': '2026-11-01T00:00:00.000Z',
        'tasks': <dynamic>[],
      }));
      File(p.join(assetsDir.path, 'tones.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 0,
        'tones': <dynamic>[],
      }));

      int migrationHookInvocations = 0;
      Map<String, dynamic> testV0ToV1(Map<String, dynamic> rawMap) {
        migrationHookInvocations++;
        final next = Map<String, dynamic>.from(rawMap);
        next['schemaVersion'] = 1;
        next['migratedByTest'] = true;
        return next;
      }

      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        migrationRunner: MigrationRunner(migrations: {0: testV0ToV1}),
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      expect(sl<DataAccessMode>().hasMigrationError, isFalse);
      expect(sl<DataAccessMode>().isReadOnly, isFalse);
      expect(migrationHookInvocations, 3); // _folder.json, list_v0.json, tones.json

      final listJson = jsonDecode(
        File(p.join(notesDir.path, 'list_v0.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final tonesJson = jsonDecode(
        File(p.join(assetsDir.path, 'tones.json')).readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(listJson['schemaVersion'], 1);
      expect(listJson['migratedByTest'], isTrue);
      expect(tonesJson['schemaVersion'], 1);
      expect(tonesJson['migratedByTest'], isTrue);

      // Tidak ada *.bak tersisa
      final bakFiles = sandboxDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.bak'))
          .toList();
      expect(bakFiles, isEmpty);

      // Simpan snapshot byte sebelum startup kedua (idempoten)
      final beforeListBytes =
          File(p.join(notesDir.path, 'list_v0.json')).readAsBytesSync();
      final beforeFolderBytes =
          File(p.join(notesDir.path, '_folder.json')).readAsBytesSync();
      final beforeTonesBytes =
          File(p.join(assetsDir.path, 'tones.json')).readAsBytesSync();
      migrationHookInvocations = 0;

      await initDependencies(
        overrideNotesDir: notesDir,
        overrideSupportDir: supportDir,
        migrationRunner: MigrationRunner(migrations: {0: testV0ToV1}),
        notificationPluginClient: fakePlugin,
        timezoneProvider: () async => currentTimezone,
      );

      expect(migrationHookInvocations, 0);
      expect(
        File(p.join(notesDir.path, 'list_v0.json')).readAsBytesSync(),
        beforeListBytes,
      );
      expect(
        File(p.join(notesDir.path, '_folder.json')).readAsBytesSync(),
        beforeFolderBytes,
      );
      expect(
        File(p.join(assetsDir.path, 'tones.json')).readAsBytesSync(),
        beforeTonesBytes,
      );
      expect(
        sandboxDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.bak'))
            .toList(),
        isEmpty,
      );
    });

    testWidgets('7b. Gagal migrasi melakukan rollback dari *.bak, tidak menimpa data, dan tampilkan layar error',
        (tester) async {
      final originalFolderJson = jsonEncode({
        'schemaVersion': 0,
        'id': 'root',
        'name': 'root',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'order': ['notes_a.json'],
      });
      final originalNoteJson = jsonEncode({
        'schemaVersion': 0,
        'id': 'note_a',
        'type': 'page',
        'title': 'Catatan Utuh',
        'colorIndex': 0,
        'createdAt': '2026-11-01T00:00:00.000Z',
        'updatedAt': '2026-11-01T00:00:00.000Z',
        'ops': <dynamic>[],
        'plainText': 'Isi tidak boleh rusak',
      });
      final originalTonesJson = jsonEncode({
        'schemaVersion': 0,
        'tones': <dynamic>[],
      });

      final folderFile = File(p.join(notesDir.path, '_folder.json'))
        ..writeAsStringSync(originalFolderJson);
      final noteFile = File(p.join(notesDir.path, 'notes_a.json'))
        ..writeAsStringSync(originalNoteJson);
      final tonesFile = File(p.join(assetsDir.path, 'tones.json'))
        ..writeAsStringSync(originalTonesJson);

      int step = 0;
      Map<String, dynamic> failingV0ToV1(Map<String, dynamic> rawMap) {
        step++;
        if (step >= 2) {
          throw StateError('Simulasi kegagalan migrasi di file kedua');
        }
        final next = Map<String, dynamic>.from(rawMap);
        next['schemaVersion'] = 1;
        next['corruptedIfNotRolledBack'] = true;
        return next;
      }

      await tester.runAsync(() async {
        await initDependencies(
          overrideNotesDir: notesDir,
          overrideSupportDir: supportDir,
          migrationRunner: MigrationRunner(migrations: {0: failingV0ToV1}),
          notificationPluginClient: fakePlugin,
          timezoneProvider: () async => currentTimezone,
        );
      });

      expect(sl<DataAccessMode>().hasMigrationError, isTrue);
      // Rollback sempurna: isi asli tetap utuh & tidak ada *.bak tersisa
      expect(folderFile.readAsStringSync(), originalFolderJson);
      expect(noteFile.readAsStringSync(), originalNoteJson);
      expect(tonesFile.readAsStringSync(), originalTonesJson);
      expect(
        sandboxDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.bak'))
            .toList(),
        isEmpty,
      );

      // UI menampilkan layar error migrasi yang jelas
      await tester.pumpWidget(const RemindingApp());
      await tester.pump();
      expect(find.byKey(const Key('migration_error_screen')), findsOneWidget);
      expect(find.textContaining('Simulasi kegagalan migrasi'), findsOneWidget);
    });

    testWidgets('7c. schemaVersion lebih baru memicu mode BACA-SAJA, tolak tulis dengan ReadOnlyDataException, dan tampilkan banner',
        (tester) async {
      AppRouter.router.go('/');

      File(p.join(notesDir.path, '_folder.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 1,
        'id': 'root',
        'name': 'root',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'order': ['future_list.json'],
      }));
      final futureListContent = jsonEncode({
        'schemaVersion': 99,
        'id': 'future_list',
        'type': 'list',
        'title': 'Daftar Versi Masa Depan',
        'colorIndex': 0,
        'createdAt': '2026-11-01T00:00:00.000Z',
        'updatedAt': '2026-11-01T00:00:00.000Z',
        'tasks': <dynamic>[],
      });
      final futureFile = File(p.join(notesDir.path, 'future_list.json'))
        ..writeAsStringSync(futureListContent);
      File(p.join(assetsDir.path, 'tones.json')).writeAsStringSync(jsonEncode({
        'schemaVersion': 1,
        'tones': <dynamic>[],
      }));

      await tester.runAsync(() async {
        await initDependencies(
          overrideNotesDir: notesDir,
          overrideSupportDir: supportDir,
          notificationPluginClient: fakePlugin,
          timezoneProvider: () async => currentTimezone,
        );
      });

      expect(sl<DataAccessMode>().isReadOnly, isTrue);
      expect(sl<DataAccessMode>().newerSchemaVersion, 99);

      await tester.runAsync(() async {
        final ds = sl<LocalStorageDataSource>();
        final tonesDs = sl<TonesLocalDataSource>();
        final repo = sl<ExplorerRepository>();
        final existingList = await ds.readList('future_list.json');

        // Semua operasi tulis ditolak dengan ReadOnlyDataException
        await expectLater(
          () => ds.writeList(existingList.copyWith(title: 'Ubah')),
          throwsA(isA<ReadOnlyDataException>()),
        );
        await expectLater(
          () => repo.createFolder(name: 'Baru', parentRelativePath: ''),
          throwsA(isA<ReadOnlyDataException>()),
        );
        await expectLater(
          () => repo.deleteEntry(existingList),
          throwsA(isA<ReadOnlyDataException>()),
        );
        await expectLater(
          () => repo.renameFile(
            fileRelativePath: existingList.relativePath,
            newTitle: 'Ubah',
          ),
          throwsA(isA<ReadOnlyDataException>()),
        );
        await expectLater(
          () => repo.copyFile(
            file: existingList,
            destinationFolderRelativePath: '',
          ),
          throwsA(isA<ReadOnlyDataException>()),
        );
        final dummyTone = File(p.join(sandboxDir.path, 'ro.mp3'))
          ..writeAsBytesSync([1, 2, 3]);
        await expectLater(
          () => tonesDs.addTone(sourceFile: dummyTone, name: 'RO'),
          throwsA(isA<ReadOnlyDataException>()),
        );
        await expectLater(
          () => sl<BackupService>().executeReplaceAll(
            extractDir: sandboxDir,
            notesDir: notesDir,
            assetsDir: assetsDir,
            tempSafetyDir: sandboxDir,
          ),
          throwsA(isA<ReadOnlyDataException>()),
        );

        // Auto-save NoteEditorBloc di mode baca-saja tidak menulis file ke disk
        final noteBloc = sl<NoteEditorBloc>();
        noteBloc.add(const InitializeNote());
        await Future<void>.delayed(const Duration(milliseconds: 60));
        noteBloc.add(const UpdateTitle('AutoSave Ditolak'));
        noteBloc.add(const SaveNoteEvent());
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await noteBloc.close();
      });

      // Tidak ada file baru di notesDir dan file asli tetap utuh
      expect(
        notesDir.listSync().whereType<File>().map((f) => p.basename(f.path)).toSet(),
        {'_folder.json', 'future_list.json'},
      );
      expect(futureFile.readAsStringSync(), futureListContent);

      // UI menampilkan banner read-only yang persis diminta
      await tester.pumpWidget(const RemindingApp());
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Data dibuat oleh versi aplikasi yang lebih baru. Mode baca saja.'),
        findsOneWidget,
      );
    });

    testWidgets('Lifecycle AppLifecycleState.resumed memanggil reconcileAllReminders dan tap payload membuka file setelah dipindah',
        (tester) async {
      AppRouter.router.go('/');

      late String payload;
      await tester.runAsync(() async {
        await initDependencies(
          overrideNotesDir: notesDir,
          overrideSupportDir: supportDir,
          notificationPluginClient: fakePlugin,
          timezoneProvider: () async => currentTimezone,
        );

        final repo = sl<ExplorerRepository>();
        final folderA = await repo.createFolder(name: 'FolderA', parentRelativePath: '');
        final folderB = await repo.createFolder(name: 'FolderB', parentRelativePath: '');

        final list = await repo.saveList(
          buildListWithDeadline(
            id: 'list_tap_moved',
            relativePath: '',
            title: 'List Sudah Dipindah',
            taskId: 'task_tap_moved',
          ),
          targetFolderRelativePath: folderA.relativePath,
        );
        payload = fakePlugin.scheduled.values.first.payload!;

        // Pindahkan file ke folderB sebelum notifikasi di-tap
        await repo.moveEntry(
          entry: list,
          destinationFolderRelativePath: folderB.relativePath,
        );
      });

      await tester.pumpWidget(const RemindingApp());
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Sisipkan notifikasi yatim lalu kirim AppLifecycleState.resumed
      fakePlugin.seedPending(
        id: 555666,
        title: 'Yatim Resume',
        body: 'Harus hilang',
        payload: jsonEncode({'fileId': 'tidak_ada', 'taskId': 'tidak_ada'}),
      );
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakePlugin.scheduled.containsKey(555666), isFalse);

      // Simulasikan tap notifikasi dengan payload lama (hanya fileId + taskId)
      final resolved = await tester.runAsync(
        () => sl<ReminderSyncService>().resolveNotificationPayload(payload),
      );
      expect(resolved, isNotNull);
      expect(resolved!.folderRelativePath, 'FolderB');

      fakePlugin.simulateTap(payload);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        if (AppRouter.router.state.uri.toString().contains('/list/') &&
            find.byKey(const Key('list_title_input')).evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        AppRouter.router.state.uri.toString(),
        contains('/list/list_tap_moved'),
      );
      expect(
        AppRouter.router.state.uri.toString(),
        contains('folder=FolderB'),
      );
      expect(find.byKey(const Key('list_title_input')), findsOneWidget);
      expect(find.text('List Sudah Dipindah'), findsOneWidget);

      // Kembalikan route ke '/' agar router bersih
      AppRouter.router.go('/');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
