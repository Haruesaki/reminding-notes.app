import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/migration/data_access_mode.dart';
import '../../../../core/utils/atomic_file_writer.dart';
import '../../../explorer/data/datasources/local_storage_data_source.dart';
import '../../../explorer/data/datasources/notes_index_manager.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../../domain/services/reminder_calculator.dart';
import '../../domain/services/reminder_sync_service.dart';
import '../datasources/tones_local_data_source.dart';
import 'notification_service.dart';

class ReminderSyncServiceImpl implements ReminderSyncService {
  final Directory notesDir;
  final Directory supportDir;
  final NotesIndexManager indexManager;
  final LocalStorageDataSource localDataSource;
  final TonesLocalDataSource tonesDataSource;
  final NotificationService notificationService;
  final DataAccessMode? dataAccessMode;
  final DateTime Function() _nowProvider;

  ReminderSyncServiceImpl({
    required this.notesDir,
    required this.supportDir,
    required this.indexManager,
    required this.localDataSource,
    required this.tonesDataSource,
    required this.notificationService,
    this.dataAccessMode,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static const String timezoneFileName = 'last_timezone.txt';

  File get timezoneFile => File(p.join(supportDir.path, timezoneFileName));

  Future<bool> _checkAndUpdateTimezone() async {
    final currentTz = await notificationService.syncTimezone();
    String? previousTz;
    if (await timezoneFile.exists()) {
      try {
        previousTz = (await timezoneFile.readAsString(encoding: utf8)).trim();
      } catch (_) {}
    }

    if (previousTz == null || previousTz.isEmpty) {
      await AtomicFileWriter.writeString(timezoneFile, '$currentTz\n');
      return false;
    }

    if (previousTz != currentTz) {
      await AtomicFileWriter.writeString(timezoneFile, '$currentTz\n');
      return true;
    }

    return false;
  }

  Future<Map<String, ToneRef>> _loadTonesMap() async {
    final tones = await tonesDataSource.getTones();
    return {for (final t in tones) t.id: t};
  }

  Future<List<ListFile>> _loadAllListFilesFromIndexAndDisk() async {
    final index = await indexManager.rebuildIndex(notesDir);
    final listFiles = <ListFile>[];
    for (final entry in index.files) {
      if (entry.type == 'list') {
        try {
          final listFile = await localDataSource.readList(entry.relativePath);
          listFiles.add(listFile);
        } catch (_) {}
      }
    }
    return listFiles;
  }

  @override
  Future<void> reconcileAllReminders({bool forceRescheduleAll = false}) async {
    if (dataAccessMode?.hasMigrationError == true) return;
    final tzChanged = await _checkAndUpdateTimezone();
    final shouldForceAll = forceRescheduleAll || tzChanged;

    final listFiles = await _loadAllListFilesFromIndexAndDisk();
    final tonesMap = await _loadTonesMap();
    final now = _nowProvider();

    final desired = <int, _DesiredSlot>{};
    for (final listFile in listFiles) {
      for (final task in listFile.tasks) {
        if (task.done || task.deadline == null) continue;
        final dl = task.deadline!;
        final slots = ReminderCalculator.calculateReminderSlots(
          deadline: dl.at,
          remindStartDaysBefore: dl.remindStartDaysBefore,
          remindTimes: dl.remindTimes,
          now: now,
        );
        final tone = dl.notificationToneId != null ? tonesMap[dl.notificationToneId!] : null;
        for (final slot in slots) {
          final notifId = ReminderCalculator.getNotificationId(task.id, slot);
          final payload = jsonEncode({'fileId': listFile.id, 'taskId': task.id});
          final body = ReminderCalculator.calculateRemainingTimeText(slot, dl.at);
          desired[notifId] = _DesiredSlot(
            id: notifId,
            task: task,
            fileId: listFile.id,
            fileTitle: listFile.title,
            slot: slot,
            deadlineAt: dl.at,
            tone: tone,
            payload: payload,
            title: task.text,
            body: body,
          );
        }
      }
    }

    final pending = await notificationService.pendingNotificationRequests();

    if (shouldForceAll) {
      for (final req in pending) {
        await notificationService.cancelById(req.id);
      }
      for (final item in desired.values) {
        await notificationService.scheduleNotificationSlot(
          notifId: item.id,
          task: item.task,
          fileTitle: item.fileTitle,
          fileId: item.fileId,
          slot: item.slot,
          deadlineAt: item.deadlineAt,
          tone: item.tone,
        );
      }
      return;
    }

    final matchedIds = <int>{};
    for (final req in pending) {
      final target = desired[req.id];
      final matches = target != null &&
          req.payload == target.payload &&
          (req.title == null || req.title == target.title) &&
          (req.body == null || req.body == target.body);
      if (!matches) {
        await notificationService.cancelById(req.id);
      } else {
        matchedIds.add(req.id);
      }
    }

    for (final item in desired.values) {
      if (!matchedIds.contains(item.id)) {
        await notificationService.scheduleNotificationSlot(
          notifId: item.id,
          task: item.task,
          fileTitle: item.fileTitle,
          fileId: item.fileId,
          slot: item.slot,
          deadlineAt: item.deadlineAt,
          tone: item.tone,
        );
      }
    }
  }

  @override
  Future<void> syncTaskReminder({
    required Task task,
    required String fileId,
    required String fileTitle,
  }) async {
    ToneRef? tone;
    final toneId = task.deadline?.notificationToneId;
    if (toneId != null && toneId.isNotEmpty) {
      tone = await tonesDataSource.getToneById(toneId);
    }
    await notificationService.scheduleTaskReminders(
      task: task,
      fileTitle: fileTitle,
      fileId: fileId,
      tone: tone,
      now: _nowProvider(),
    );
  }

  @override
  Future<void> cancelTaskReminders(String taskId) {
    return notificationService.cancelTaskReminders(taskId);
  }

  @override
  Future<void> syncListFile(ListFile listFile, {ListFile? previousList}) async {
    final tonesMap = await _loadTonesMap();
    final now = _nowProvider();
    final prevById = {
      if (previousList != null)
        for (final t in previousList.tasks) t.id: t,
    };

    final desired = <int, _DesiredSlot>{};
    final forceTaskIds = <String>{};

    for (final task in listFile.tasks) {
      final prev = prevById[task.id];
      if (prev != null && prev.deadline != task.deadline) {
        forceTaskIds.add(task.id);
      }
      if (task.done || task.deadline == null) continue;
      final dl = task.deadline!;
      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: dl.at,
        remindStartDaysBefore: dl.remindStartDaysBefore,
        remindTimes: dl.remindTimes,
        now: now,
      );
      final tone = dl.notificationToneId != null ? tonesMap[dl.notificationToneId!] : null;
      for (final slot in slots) {
        final notifId = ReminderCalculator.getNotificationId(task.id, slot);
        final payload = jsonEncode({'fileId': listFile.id, 'taskId': task.id});
        final body = ReminderCalculator.calculateRemainingTimeText(slot, dl.at);
        desired[notifId] = _DesiredSlot(
          id: notifId,
          task: task,
          fileId: listFile.id,
          fileTitle: listFile.title,
          slot: slot,
          deadlineAt: dl.at,
          tone: tone,
          payload: payload,
          title: task.text,
          body: body,
        );
      }
    }

    final pending = await notificationService.pendingNotificationRequests();
    final matchedIds = <int>{};

    for (final req in pending) {
      if (req.payload == null) continue;
      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(req.payload!) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final reqFileId = decoded['fileId'] as String?;
      final reqTaskId = decoded['taskId'] as String?;
      final belongsToFile = reqFileId == listFile.id ||
          (reqTaskId != null && listFile.tasks.any((t) => t.id == reqTaskId)) ||
          (reqTaskId != null && prevById.containsKey(reqTaskId));

      if (!belongsToFile) continue;

      final target = desired[req.id];
      final forcedReschedule = reqTaskId != null && forceTaskIds.contains(reqTaskId);
      final matches = !forcedReschedule &&
          target != null &&
          req.payload == target.payload &&
          (req.title == null || req.title == target.title) &&
          (req.body == null || req.body == target.body);

      if (!matches) {
        await notificationService.cancelById(req.id);
      } else {
        matchedIds.add(req.id);
      }
    }

    for (final item in desired.values) {
      if (!matchedIds.contains(item.id)) {
        await notificationService.scheduleNotificationSlot(
          notifId: item.id,
          task: item.task,
          fileTitle: item.fileTitle,
          fileId: item.fileId,
          slot: item.slot,
          deadlineAt: item.deadlineAt,
          tone: item.tone,
        );
      }
    }
  }

  @override
  Future<void> cancelListFileReminders(ListFile listFile) async {
    await notificationService.cancelFileReminders(listFile.id);
    for (final task in listFile.tasks) {
      await notificationService.cancelTaskReminders(task.id);
    }
  }

  @override
  Future<void> cancelFolderReminders(List<ListFile> listFiles) async {
    for (final listFile in listFiles) {
      await cancelListFileReminders(listFile);
    }
  }

  @override
  Future<void> syncAfterToneDeleted(String toneId) async {
    await reconcileAllReminders(forceRescheduleAll: true);
  }

  @override
  Future<ResolvedNotificationTarget?> resolveNotificationPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return null;

    String? fileId;
    String? taskId;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        fileId = decoded['fileId'] as String?;
        taskId = decoded['taskId'] as String?;
      }
    } catch (_) {
      return null;
    }

    if (fileId == null || fileId.isEmpty) return null;

    var index = await indexManager.loadIndex();
    IndexFileEntry? match;
    for (final f in index.files) {
      if (f.id == fileId) {
        match = f;
        break;
      }
    }

    // Jika belum ada di indeks atau path lama tidak ditemukan di disk, bangun ulang indeks lalu cek lagi.
    final diskFileExists = match != null &&
        File(p.join(notesDir.path, match.relativePath)).existsSync();
    if (match == null || !diskFileExists) {
      index = await indexManager.rebuildIndex(notesDir);
      match = null;
      for (final f in index.files) {
        if (f.id == fileId) {
          match = f;
          break;
        }
      }
    }

    if (match == null) return null;

    try {
      final fileEntry = await localDataSource.readFile(match.relativePath);
      final dir = p.dirname(match.relativePath).replaceAll(r'\', '/');
      final folderRel = (dir == '.' || dir.isEmpty) ? '' : dir;
      return ResolvedNotificationTarget(
        fileId: fileId,
        taskId: taskId,
        fileEntry: fileEntry,
        folderRelativePath: folderRel,
      );
    } catch (_) {
      return null;
    }
  }
}

class _DesiredSlot {
  final int id;
  final Task task;
  final String fileId;
  final String fileTitle;
  final DateTime slot;
  final DateTime deadlineAt;
  final ToneRef? tone;
  final String payload;
  final String title;
  final String body;

  const _DesiredSlot({
    required this.id,
    required this.task,
    required this.fileId,
    required this.fileTitle,
    required this.slot,
    required this.deadlineAt,
    required this.tone,
    required this.payload,
    required this.title,
    required this.body,
  });
}
