import '../../../explorer/domain/entities/entities.dart';

class ResolvedNotificationTarget {
  final String fileId;
  final String? taskId;
  final FileEntry fileEntry;
  final String folderRelativePath;

  const ResolvedNotificationTarget({
    required this.fileId,
    required this.taskId,
    required this.fileEntry,
    required this.folderRelativePath,
  });
}

/// Satu titik sinkronisasi pengingat di domain layer.
abstract class ReminderSyncService {
  /// Rekonsiliasi semua pengingat terhadap data disk/indeks dan cek perubahan zona waktu.
  Future<void> reconcileAllReminders({bool forceRescheduleAll = false});

  /// Sinkronkan satu task (batalkan jadwal lama; jadwalkan ulang jika aktif & ber-deadline).
  Future<void> syncTaskReminder({
    required Task task,
    required String fileId,
    required String fileTitle,
  });

  /// Batalkan semua jadwal milik satu task.
  Future<void> cancelTaskReminders(String taskId);

  /// Sinkronkan seluruh task dalam satu ListFile.
  Future<void> syncListFile(ListFile listFile, {ListFile? previousList});

  /// Batalkan semua jadwal milik satu ListFile.
  Future<void> cancelListFileReminders(ListFile listFile);

  /// Batalkan semua jadwal milik seluruh ListFile dalam folder (rekursif).
  Future<void> cancelFolderReminders(List<ListFile> listFiles);

  /// Jadwalkan ulang setelah nada kustom dihapus.
  Future<void> syncAfterToneDeleted(String toneId);

  /// Resolusi payload notifikasi (`fileId` + `taskId`) ke path terbaru via indeks.
  Future<ResolvedNotificationTarget?> resolveNotificationPayload(String? payload);
}
