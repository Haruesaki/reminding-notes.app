import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reminding/features/notes/domain/services/reminder_calculator.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ReminderCalculator (PRD 8.1)', () {
    test('contoh PRD 8.1: deadline 26 Apr 20:00, N=3, jam 09:00/15:00/20:00', () {
      final deadline = DateTime(2026, 4, 26, 20, 0);
      const remindStartDaysBefore = 3;
      const remindTimes = ['09:00', '15:00', '20:00'];
      final now = DateTime(2026, 4, 22, 10, 0);

      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: deadline,
        remindStartDaysBefore: remindStartDaysBefore,
        remindTimes: remindTimes,
        now: now,
      );

      // Expected: 23, 24, 25 Apr (3x/hari) + 26 Apr (09:00 dan 15:00)
      // 26 Apr 20:00 tidak dijadwalkan karena sama dengan waktu deadline.
      expect(slots.length, 11);

      // 23 April
      expect(slots[0], DateTime(2026, 4, 23, 9, 0));
      expect(slots[1], DateTime(2026, 4, 23, 15, 0));
      expect(slots[2], DateTime(2026, 4, 23, 20, 0));

      // 24 April
      expect(slots[3], DateTime(2026, 4, 24, 9, 0));
      expect(slots[4], DateTime(2026, 4, 24, 15, 0));
      expect(slots[5], DateTime(2026, 4, 24, 20, 0));

      // 25 April
      expect(slots[6], DateTime(2026, 4, 25, 9, 0));
      expect(slots[7], DateTime(2026, 4, 25, 15, 0));
      expect(slots[8], DateTime(2026, 4, 25, 20, 0));

      // 26 April
      expect(slots[9], DateTime(2026, 4, 26, 9, 0));
      expect(slots[10], DateTime(2026, 4, 26, 15, 0));
    });

    test('H-0: hanya menjadwalkan pada hari yang sama sebelum waktu deadline', () {
      final deadline = DateTime(2026, 4, 26, 20, 0);
      const remindStartDaysBefore = 0;
      const remindTimes = ['09:00', '15:00', '20:00'];
      final now = DateTime(2026, 4, 26, 8, 0);

      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: deadline,
        remindStartDaysBefore: remindStartDaysBefore,
        remindTimes: remindTimes,
        now: now,
      );

      // Hanya 26 Apr 09:00 dan 15:00
      expect(slots.length, 2);
      expect(slots[0], DateTime(2026, 4, 26, 9, 0));
      expect(slots[1], DateTime(2026, 4, 26, 15, 0));
    });

    test('jam ganda / duplikat otomatis dibersihkan dan diurutkan', () {
      final deadline = DateTime(2026, 4, 26, 20, 0);
      const remindStartDaysBefore = 0;
      const remindTimes = ['15:00', '09:00', '09:00', '15:00'];
      final now = DateTime(2026, 4, 26, 8, 0);

      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: deadline,
        remindStartDaysBefore: remindStartDaysBefore,
        remindTimes: remindTimes,
        now: now,
      );

      expect(slots.length, 2);
      expect(slots[0], DateTime(2026, 4, 26, 9, 0));
      expect(slots[1], DateTime(2026, 4, 26, 15, 0));
    });

    test('deadline lampau tidak menghasilkan jadwal notifikasi', () {
      final deadline = DateTime(2026, 4, 20, 10, 0);
      const remindStartDaysBefore = 3;
      const remindTimes = ['09:00', '15:00', '20:00'];
      final now = DateTime(2026, 4, 26, 12, 0);

      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: deadline,
        remindStartDaysBefore: remindStartDaysBefore,
        remindTimes: remindTimes,
        now: now,
      );

      expect(slots, isEmpty);
    });

    test('slot yang sudah lewat hari ini tidak dijadwalkan ulang', () {
      final deadline = DateTime(2026, 4, 26, 20, 0);
      const remindStartDaysBefore = 0;
      const remindTimes = ['09:00', '15:00', '18:00'];
      final now = DateTime(2026, 4, 26, 10, 0); // lewat dari 09:00

      final slots = ReminderCalculator.calculateReminderSlots(
        deadline: deadline,
        remindStartDaysBefore: remindStartDaysBefore,
        remindTimes: remindTimes,
        now: now,
      );

      expect(slots.length, 2);
      expect(slots[0], DateTime(2026, 4, 26, 15, 0));
      expect(slots[1], DateTime(2026, 4, 26, 18, 0));
    });
  });

  group('calculateRemainingTimeText (PRD 8.1)', () {
    test('>= 1 hari menampilkan X hari Y jam', () {
      final notif = DateTime(2026, 4, 23, 9, 0);
      final deadline = DateTime(2026, 4, 26, 20, 0);
      // Selisih: 3 hari 11 jam
      final text = ReminderCalculator.calculateRemainingTimeText(notif, deadline);
      expect(text, 'Deadline tinggal 3 hari 11 jam');
    });

    test('persis 1 hari menampilkan 1 hari 0 jam', () {
      final notif = DateTime(2026, 4, 25, 20, 0);
      final deadline = DateTime(2026, 4, 26, 20, 0);
      final text = ReminderCalculator.calculateRemainingTimeText(notif, deadline);
      expect(text, 'Deadline tinggal 1 hari 0 jam');
    });

    test('< 1 hari menampilkan X jam Y menit', () {
      final notif = DateTime(2026, 4, 26, 9, 15);
      final deadline = DateTime(2026, 4, 26, 20, 0);
      // Selisih: 10 jam 45 menit
      final text = ReminderCalculator.calculateRemainingTimeText(notif, deadline);
      expect(text, 'Deadline tinggal 10 jam 45 menit');
    });

    test('< 1 jam menampilkan 0 jam X menit', () {
      final notif = DateTime(2026, 4, 26, 19, 15);
      final deadline = DateTime(2026, 4, 26, 20, 0);
      final text = ReminderCalculator.calculateRemainingTimeText(notif, deadline);
      expect(text, 'Deadline tinggal 0 jam 45 menit');
    });
  });

  group('DeadlineBadgeStatus & format (PRD 7.1, 7.5)', () {
    test('< 3 hari atau sudah lewat berwarna urgent (merah)', () {
      final now = DateTime(2026, 5, 1, 10, 0);
      // Lampau
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 4, 30, 20, 0), now),
        DeadlineBadgeStatus.urgent,
      );
      // Hari ini (0 hari)
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 5, 1, 15, 0), now),
        DeadlineBadgeStatus.urgent,
      );
      // 2 hari lagi
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 5, 3, 20, 0), now),
        DeadlineBadgeStatus.urgent,
      );
    });

    test('3-7 hari berstatus netral', () {
      final now = DateTime(2026, 5, 1, 10, 0);
      // 3 hari lagi (4 Mei)
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 5, 4, 10, 0), now),
        DeadlineBadgeStatus.neutral,
      );
      // 7 hari lagi (8 Mei)
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 5, 8, 10, 0), now),
        DeadlineBadgeStatus.neutral,
      );
    });

    test('> 7 hari berstatus relaxed (hijau)', () {
      final now = DateTime(2026, 5, 1, 10, 0);
      // 8 hari lagi (9 Mei)
      expect(
        ReminderCalculator.getDeadlineBadgeStatus(DateTime(2026, 5, 9, 10, 0), now),
        DeadlineBadgeStatus.relaxed,
      );
    });

    test('formatDeadlineBadge menghasilkan format d MMM, HH:mm', () {
      final dt = DateTime(2026, 11, 12, 20, 0);
      final text = ReminderCalculator.formatDeadlineBadge(dt);
      expect(text, '12 Nov, 20:00');
    });
  });
}
