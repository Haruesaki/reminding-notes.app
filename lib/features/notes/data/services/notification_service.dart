import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../../features/explorer/domain/entities/list_file.dart';
import '../../../../features/explorer/domain/entities/task.dart';
import '../../../../features/explorer/domain/entities/tone_ref.dart';
import '../../domain/services/reminder_calculator.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin plugin;
  bool _initialized = false;
  void Function(String payload)? onNotificationTap;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String defaultChannelId = 'reminder_default';
  static const String defaultChannelName = 'Pengingat Default';

  Future<void> init({void Function(String payload)? onNotificationTap}) async {
    if (_initialized) return;
    this.onNotificationTap = onNotificationTap;

    // Timezone setup
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Timezone initialization fallback: $e');
    }

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
      await plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && this.onNotificationTap != null) {
            this.onNotificationTap!(response.payload!);
          }
        },
      );
    } catch (e) {
      debugPrint('Notification plugin init error: $e');
    }

    // Buat channel default di Android
    try {
      if (Platform.isAndroid) {
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          const channel = AndroidNotificationChannel(
            defaultChannelId,
            defaultChannelName,
            description: 'Notifikasi pengingat tenggat waktu tugas',
            importance: Importance.max,
          );
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    } catch (e) {
      debugPrint('Channel creation error: $e');
    }

    _initialized = true;
  }

  /// Membatalkan semua notifikasi milik satu task
  Future<void> cancelTaskReminders(String taskId) async {
    try {
      final pending = await plugin.pendingNotificationRequests();
      for (final req in pending) {
        if (req.payload != null) {
          try {
            final data = jsonDecode(req.payload!) as Map<String, dynamic>;
            if (data['taskId'] == taskId) {
              await plugin.cancel(id: req.id);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error cancelling task reminders: $e');
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

    // Persiapan channel nada kustom jika ada
    String channelId = defaultChannelId;
    String channelName = defaultChannelName;
    AndroidNotificationSound? androidSound;

    if (tone != null) {
      channelId = 'reminder_${tone.id}';
      channelName = 'Pengingat - ${tone.name}';
      if (tone.contentUri != null && tone.contentUri!.isNotEmpty) {
        androidSound = UriAndroidNotificationSound(tone.contentUri!);
      }

      if (Platform.isAndroid) {
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final customChannel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: 'Pengingat dengan nada ${tone.name}',
            importance: Importance.max,
            sound: androidSound,
          );
          await androidPlugin.createNotificationChannel(customChannel);
        }
      }
    }

    for (final slot in slots) {
      final notifId = ReminderCalculator.getNotificationId(task.id, slot);
      final remainingText = ReminderCalculator.calculateRemainingTimeText(slot, dl.at);
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
        final tzScheduledDate = tz.TZDateTime.from(slot, tz.local);
        await plugin.zonedSchedule(
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
