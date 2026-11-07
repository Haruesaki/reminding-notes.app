import 'dart:io';
import 'package:flutter/services.dart';

class MediaStoreService {
  static const MethodChannel _channel = MethodChannel('com.example.reminding/media_store');

  /// Mendaftarkan file audio ke MediaStore sistem Android agar bisa diakses
  /// sebagai notifikasi/ringtone oleh system_server.
  Future<String?> registerToneToMediaStore({
    required String filePath,
    required String title,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final uri = await _channel.invokeMethod<String>('registerTone', {
        'filePath': filePath,
        'title': title,
      });
      return uri;
    } catch (_) {
      return null;
    }
  }

  /// Menghapus file nada dari MediaStore
  Future<void> deleteToneFromMediaStore(String contentUri) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('deleteTone', {'contentUri': contentUri});
    } catch (_) {}
  }

  /// Menghapus notification channel kustom
  Future<void> deleteNotificationChannel(String channelId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('deleteNotificationChannel', {'channelId': channelId});
    } catch (_) {}
  }
}
