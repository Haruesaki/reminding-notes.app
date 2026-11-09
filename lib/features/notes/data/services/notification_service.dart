import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../../features/explorer/domain/entities/list_file.dart';
import '../../../../features/explorer/domain/entities/task.dart';
import '../../../../features/explorer/domain/entities/tone_ref.dart';
import '../../domain/services/reminder_calculator.dart';
import 'notification_plugin_client.dart';

class NotificationService {
  final NotificationPluginClient _pluginClient;
  final Future<String> Function() _timezoneProvider;
  bool _initialized = false;
  bool _tzInitialized = false;
  void Function(String payload)? onNotificationTap;
  String? _pendingLaunchPayload;
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPluginClient? pluginClient,
    Future<String> Function()? timezoneProvider,
  })  : _pluginClient =
            pluginClient ?? FlutterNotificationPluginClient(plugin: plugin),
        _timezoneProvider = timezoneProvider ?? _defaultTimezoneProvider;

  static const String defaultChannelId = 'reminder_default';
  static const String defaultChannelName = 'Pengingat Default';

  Stream<String> get onNotificationTapStream => _tapController.stream;

  String? consumeLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  @visibleForTesting
  void simulateNotificationTap(String payload) {
    onNotificationTap?.call(payload);
    _tapController.add(payload);
  }

  static Future<String> _defaultTimezoneProvider() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      return timezoneInfo.identifier;
    } catch (_) {
      return 'UTC';
    }
  }

  void _ensureTimezonesInitialized() {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    _tzInitialized = true;
  }

  Future<String> syncTimezone() async {
    _ensureTimezonesInitialized();
    try {
      final tzName = (await _timezoneProvider()).trim();
      final resolved = tzName.isEmpty ? 'UTC' : tzName;
      tz.setLocalLocation(tz.getLocation(resolved));
      return resolved;
    } catch (e) {
      debugPrint('Timezone initialization fallback: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
      return 'UTC';
    }
  }

  Future<void> init({void Function(String payload)? onNotificationTap}) async {
    if (onNotificationTap != null) {
      this.onNotificationTap = onNotificationTap;
    }
    if (_initialized) return;

    await syncTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _pluginClient.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            this.onNotificationTap?.call(payload);
            _tapController.add(payload);
          }
        },
      );
      _pendingLaunchPayload = await _pluginClient.getLaunchNotificationPayload();
    } catch (e) {
      debugPrint('Notification plugin init error: $e');
    }

    // Buat channel default di Android
    try {
      const channel = AndroidNotificationChannel(
        defaultChannelId,
        defaultChannelName,
        description: 'Notifikasi pengingat tenggat waktu tugas',
        importance: Importance.max,
      );
      await _pluginClient.createAndroidNotificationChannel(channel);
    } catch (e) {
      debugPrint('Channel creation error: $e');
    }

    _initialized = true;
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    try {
      return await _pluginClient.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error listing pending notifications: $e');
      return const [];
    }
  }

  Future<void> cancelById(int id) async {
    try {
      await _pluginClient.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification $id: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _pluginClient.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Membatalkan semua notifikasi milik satu task
  Future<void> cancelTaskReminders(String taskId) async {
    try {
      final pending = await _pluginClient.pendingNotificationRequests();
      for (final req in pending) {
        if (req.payload != null) {
          try {
            final data = jsonDecode(req.payload!) as Map<String, dynamic>;
            if (data['taskId'] == taskId) {
              await _pluginClient.cancel(req.id);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error cancelling task reminders: $e');
    }
  }

  /// Membatalkan semua notifikasi milik satu file (berdasarkan `fileId` pada payload).
  Future<void> cancelFileReminders(String fileId) async {
    try {
      final pending = await _pluginClient.pendingNotificationRequests();
      for (final req in pending) {
        if (req.payload != null) {
          try {
            final data = jsonDecode(req.payload!) as Map<String, dynamic>;
            if (data['fileId'] == fileId) {
              await _pluginClient.cancel(req.id);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error cancelling file reminders: $e');
    }
  }

  Future<void> scheduleNotificationSlot({
    required int notifId,
    required Task task,
    required String fileTitle,
    required String fileId,
    required DateTime slot,
    required DateTime deadlineAt,
    ToneRef? tone,
  }) async {
    _ensureTimezonesInitialized();

    String channelId = defaultChannelId;
    String channelName = defaultChannelName;
    AndroidNotificationSound? androidSound;

    if (tone != null) {
      channelId = 'reminder_${tone.id}';
      channelName = 'Pengingat - ${tone.name}';
      if (tone.contentUri != null && tone.contentUri!.isNotEmpty) {
        androidSound = UriAndroidNotificationSound(tone.contentUri!);
      }

      try {
        final customChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Pengingat dengan nada ${tone.name}',
          importance: Importance.max,
          sound: androidSound,
        );
        await _pluginClient.createAndroidNotificationChannel(customChannel);
      } catch (e) {
        debugPrint('Custom channel creation error: $e');
      }
    }

    final remainingText = ReminderCalculator.calculateRemainingTimeText(slot, deadlineAt);
    final payload = jsonEncode({
      'fileId': fileId,
      'taskId': task.id,
    });

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Pengingat tenggat waktu',
      importance: Importance.max,
      priority: Priority.high,
      sound: androidSound,
      styleInformation: BigTextStyleInformation(
        remainingText,
        contentTitle: task.text,
        summaryText: fileTitle,
      ),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      final tzScheduledDate = slot.isUtc
          ? tz.TZDateTime.from(slot, tz.local)
          : tz.TZDateTime(
              tz.local,
              slot.year,
              slot.month,
              slot.day,
              slot.hour,
              slot.minute,
              slot.second,
            );
      await _pluginClient.zonedSchedule(
        id: notifId,
        title: task.text,
        body: remainingText,
        scheduledDate: tzScheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification slot $slot: $e');
    }
  }

  /// Menjadwalkan notifikasi untuk task ber-deadline sesuai PRD 8.1 - 8.3
  Future<void> scheduleTaskReminders({
    required Task task,
    required String fileTitle,
    required String fileId,
    ToneRef? tone,
    DateTime? now,
  }) async {
    // Selalu batalkan jadwal lama untuk task ini terlebih dahulu
    await cancelTaskReminders(task.id);

    // Jika task sudah selesai atau tidak punya deadline, tidak perlu dijadwalkan
    final dl = task.deadline;
    if (task.done || dl == null) {
      return;
    }

    final currentTime = now ?? DateTime.now();
    final slots = ReminderCalculator.calculateReminderSlots(
      deadline: dl.at,
      remindStartDaysBefore: dl.remindStartDaysBefore,
      remindTimes: dl.remindTimes,
      now: currentTime,
    );

    if (slots.isEmpty) {
      return;
    }

    for (final slot in slots) {
      final notifId = ReminderCalculator.getNotificationId(task.id, slot);
      await scheduleNotificationSlot(
        notifId: notifId,
        task: task,
        fileTitle: fileTitle,
        fileId: fileId,
        slot: slot,
        deadlineAt: dl.at,
        tone: tone,
      );
    }
  }

  /// Rekonsiliasi semua pengingat pada pembukaan aplikasi atau reboot (PRD 8.2)
  Future<void> reconcileAllReminders({
    required List<ListFile> listFiles,
    Map<String, ToneRef>? tonesMap,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    for (final listFile in listFiles) {
      for (final task in listFile.tasks) {
        if (task.done || task.deadline == null) {
          await cancelTaskReminders(task.id);
        } else {
          final toneId = task.deadline?.notificationToneId;
          final tone = (toneId != null && tonesMap != null) ? tonesMap[toneId] : null;
          await scheduleTaskReminders(
            task: task,
            fileTitle: listFile.title,
            fileId: listFile.id,
            tone: tone,
            now: currentTime,
          );
        }
      }
    }
  }
}
