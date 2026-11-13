import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/app_logger.dart';

class PermissionService {
  /// Meminta izin notifikasi saat pengguna menyimpan deadline pertama kali (PRD 8.4)
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        return true;
      }
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e, st) {
      AppLogger.error(e, st);
      return true;
    }
  }

  /// Membuka pengaturan aplikasi jika pengguna menolak izin
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e, st) {
      AppLogger.error(e, st);
      return false;
    }
  }
}
