import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Abstraksi tipis di atas `FlutterLocalNotificationsPlugin` agar penjadwalan,
/// pembatalan, pending requests, dan tap notifikasi dapat diuji penuh dengan fake.
abstract class NotificationPluginClient {
  Future<void> initialize({
    required InitializationSettings settings,
    required void Function(NotificationResponse response)
        onDidReceiveNotificationResponse,
  });

  Future<String?> getLaunchNotificationPayload();

  Future<void> createAndroidNotificationChannel(
    AndroidNotificationChannel channel,
  );

  Future<void> zonedSchedule({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();

  Future<List<PendingNotificationRequest>> pendingNotificationRequests();
}

class FlutterNotificationPluginClient implements NotificationPluginClient {
  final FlutterLocalNotificationsPlugin plugin;

  FlutterNotificationPluginClient({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize({
    required InitializationSettings settings,
    required void Function(NotificationResponse response)
        onDidReceiveNotificationResponse,
  }) async {
    await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  @override
  Future<String?> getLaunchNotificationPayload() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }

  @override
  Future<void> createAndroidNotificationChannel(
    AndroidNotificationChannel channel,
  ) async {
    if (!Platform.isAndroid) return;
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) {
    return plugin.zonedSchedule(
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
  Future<void> cancel(int id) {
    return plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() {
    return plugin.cancelAll();
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() {
    return plugin.pendingNotificationRequests();
  }
}
