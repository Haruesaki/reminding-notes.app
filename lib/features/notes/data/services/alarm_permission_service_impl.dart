import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:reminding/core/utils/app_logger.dart';
import 'package:reminding/features/notes/domain/services/alarm_permission_service.dart';

/// Implementasi [AlarmPermissionService] menggunakan
/// `flutter_local_notifications` (versi 23.0.0).
///
/// API yang terverifikasi dari sumber paket:
/// - `AndroidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission()`
///   membuka layar pengaturan alarm presisi khusus aplikasi (Android).
/// - Method channel `dexterous.com/flutter/local_notifications` dengan method
///   `canScheduleExactNotifications` mengembalikan bool (native:
///   `AlarmManager.canScheduleExactAlarms()`).
class AlarmPermissionServiceImpl implements AlarmPermissionService {
  static const String _channelName = 'dexterous.com/flutter/local_notifications';
  static const String _canScheduleMethod = 'canScheduleExactNotifications';

  final MethodChannel _channel;
  final FlutterLocalNotificationsPlugin _notifications;

  AlarmPermissionServiceImpl({
    MethodChannel? channel,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    try {
      final result = await _channel.invokeMethod<bool>(_canScheduleMethod);
      return result == true;
    } catch (e, st) {
      // Tidak dapat mengecek; asumsikan tidak tersedia agar fallback aktif.
      AppLogger.error(e, st);
      return false;
    }
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    try {
      final android =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestExactAlarmsPermission();
      return granted == true;
    } catch (e, st) {
      AppLogger.error(e, st);
      return false;
    }
  }

  @override
  Future<AlarmPermissionStatus> alarmPermissionStatus() async {
    if (!Platform.isAndroid) return AlarmPermissionStatus.unavailable;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AlarmPermissionStatus.unavailable;
    }

    final can = await canScheduleExactAlarms();
    if (can) return AlarmPermissionStatus.granted;
    return AlarmPermissionStatus.denied;
  }
}
