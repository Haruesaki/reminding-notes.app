import 'package:intl/intl.dart';

enum DeadlineBadgeStatus {
  urgent, // < 3 hari termasuk lewat (merah)
  relaxed, // > 7 hari (hijau)
  neutral, // 3 - 7 hari (netral)
}

class ReminderCalculator {
  /// Menghitung slot notifikasi pengingat sesuai PRD 8.1
  /// - Dari H-N (N = remindStartDaysBefore) sampai hari deadline
  /// - Hanya slot yang waktunya di masa depan (isAfter(now))
  /// - Hanya slot yang waktunya sebelum waktu deadline (isBefore(deadline))
  static List<DateTime> calculateReminderSlots({
    required DateTime deadline,
    required int remindStartDaysBefore,
    required List<String> remindTimes,
    required DateTime now,
  }) {
    if (deadline.isBefore(now)) {
      return const [];
    }

    final sanitizedDays = remindStartDaysBefore.clamp(0, 30);

    // Hapus duplikat dan urutkan jam pengingat
    final uniqueTimes = remindTimes.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    final slots = <DateTime>[];

    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);

    for (int dayOffset = sanitizedDays; dayOffset >= 0; dayOffset--) {
      final targetDate = deadlineDate.subtract(Duration(days: dayOffset));

      for (final timeStr in uniqueTimes) {
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final slotTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );

        if (slotTime.isAfter(now) && slotTime.isBefore(deadline)) {
          slots.add(slotTime);
        }
      }
    }

    slots.sort((a, b) => a.compareTo(b));
    return slots;
  }

  /// Menghitung teks sisa waktu sesuai PRD 8.1:
  /// - >= 1 hari: "Deadline tinggal {X} hari {Y} jam"
  /// - < 1 hari: "Deadline tinggal {X} jam {Y} menit"
  static String calculateRemainingTimeText(
    DateTime notificationTime,
    DateTime deadlineTime,
  ) {
    final diff = deadlineTime.difference(notificationTime);
    if (diff.isNegative) {
      return 'Deadline telah lewat';
    }

    final totalDays = diff.inDays;
    final totalHours = diff.inHours;

    if (totalDays >= 1) {
      final remainingHours = totalHours.remainder(24);
      return 'Deadline tinggal $totalDays hari $remainingHours jam';
    } else {
      final remainingMinutes = diff.inMinutes.remainder(60);
      return 'Deadline tinggal $totalHours jam $remainingMinutes menit';
    }
  }

  /// Status warna lencana deadline (PRD 7.1, 7.5):
  /// - < 3 hari termasuk lewat: urgent (merah)
  /// - > 7 hari: relaxed (hijau)
  /// - 3 - 7 hari: neutral
  static DeadlineBadgeStatus getDeadlineBadgeStatus(
    DateTime deadline,
    DateTime now,
  ) {
    if (deadline.isBefore(now)) {
      return DeadlineBadgeStatus.urgent;
    }

    final deadlineCal = DateTime(deadline.year, deadline.month, deadline.day);
    final nowCal = DateTime(now.year, now.month, now.day);
    final daysDiff = deadlineCal.difference(nowCal).inDays;

    if (daysDiff < 3) {
      return DeadlineBadgeStatus.urgent;
    } else if (daysDiff > 7) {
      return DeadlineBadgeStatus.relaxed;
    } else {
      return DeadlineBadgeStatus.neutral;
    }
  }

  /// Format teks lencana deadline, misal: "12 Nov, 20:00"
  static String formatDeadlineBadge(DateTime deadline) {
    return DateFormat('d MMM, HH:mm', 'id_ID').format(deadline);
  }

  /// ID notifikasi deterministik 31-bit integer
  static int getNotificationId(String taskId, DateTime slotTime) {
    return Object.hash(taskId, slotTime.millisecondsSinceEpoch) & 0x7FFFFFFF;
  }
}
