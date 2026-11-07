import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';

enum AlarmResult {
  success,
  unsupportedPlatform,
  failedNoClockApp,
}

class AlarmService {
  /// Membuat alarm di aplikasi Jam bawaan ponsel lewat Android Intent SET_ALARM
  Future<AlarmResult> createAlarm({
    required DateTime scheduledTime,
    required String message,
    String? ringtoneUri,
  }) async {
    if (!Platform.isAndroid) {
      return AlarmResult.unsupportedPlatform;
    }

    try {
      final arguments = <String, dynamic>{
        'android.intent.extra.alarm.HOUR': scheduledTime.hour,
        'android.intent.extra.alarm.MINUTES': scheduledTime.minute,
        'android.intent.extra.alarm.MESSAGE': message,
        'android.intent.extra.alarm.SKIP_UI': true,
      };

      if (ringtoneUri != null && ringtoneUri.isNotEmpty) {
        arguments['android.intent.extra.alarm.RINGTONE'] = ringtoneUri;
      }

      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: arguments,
      );

      await intent.launch();
      return AlarmResult.success;
    } catch (_) {
      return AlarmResult.failedNoClockApp;
    }
  }
}
