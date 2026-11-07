import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reminding/core/theme/app_colors.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'package:reminding/features/notes/domain/services/reminder_calculator.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_state.dart';
import 'package:reminding/features/notes/presentation/cubit/deadline_calendar_cubit.dart';
import 'package:reminding/features/notes/presentation/pages/reminders_page.dart';
import 'package:reminding/features/notes/presentation/widgets/date_selector_strip.dart';
import 'package:reminding/features/notes/presentation/widgets/home_header.dart';

class FakeCalendarExplorerRepository extends Fake implements ExplorerRepository {
  List<DeadlineItem> deadlines = [];
  List<NodeEntry> contents = [];

  @override
  Future<List<DeadlineItem>> getAllDeadlines() async => deadlines;

  @override
  Future<List<NodeEntry>> getFolderContents(String relativePath) async =>
      contents;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Aturan Warna Deadline (PRD 7.1 Point 1 & 5)', () {
    final now = DateTime(2026, 4, 10, 12, 0);

    test('batas 2 hari (< 3 hari): merah #E5484D', () {
      final targetDate = DateTime(2026, 4, 12); // selisih 2 hari
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.urgent);
    });

    test('batas 3 hari (3-7 hari): netral', () {
      final targetDate = DateTime(2026, 4, 13); // selisih 3 hari
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.neutral);
    });

    test('batas 7 hari (3-7 hari): netral', () {
      final targetDate = DateTime(2026, 4, 17); // selisih 7 hari
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.neutral);
    });

    test('batas 8 hari (> 7 hari): hijau #30A46C', () {
      final targetDate = DateTime(2026, 4, 18); // selisih 8 hari
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.relaxed);
    });

    test('overdue (tanggal kemarin / selisih negatif): merah #E5484D', () {
      final targetDate = DateTime(2026, 4, 9); // selisih -1 hari
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.urgent);
    });

    test('hari H (selisih 0 hari): merah #E5484D', () {
      final targetDate = DateTime(2026, 4, 10); // hari H
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: true,
      );
      expect(status, DeadlineBadgeStatus.urgent);
    });

    test('task selesai (done == true): diabaikan (status null)', () {
      final targetDate = DateTime(2026, 4, 12);
      final status = ReminderCalculator.calculateDateDeadlineStatus(
        targetDate: targetDate,
        now: now,
        hasUndoneTask: false,
      );
      expect(status, isNull);
    });
  });

  group('DeadlineCalendarCubit Logic & State', () {
    late FakeCalendarExplorerRepository repository;
    final now = DateTime(2026, 4, 10, 10, 0);

    setUp(() {
      repository = FakeCalendarExplorerRepository();
    });

    test('memetakan tanggal ke warna dan mengabaikan task selesai', () async {
      repository.deadlines = [
        // 2 hari lagi (merah)
        DeadlineItem(
          taskId: 't1',
          fileId: 'f1',
          fileTitle: 'Belanja',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Susu',
          at: DateTime(2026, 4, 12, 14, 0),
          done: false,
        ),
        // 5 hari lagi (netral)
        DeadlineItem(
          taskId: 't2',
          fileId: 'f1',
          fileTitle: 'Belanja',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Roti',
          at: DateTime(2026, 4, 15, 10, 0),
          done: false,
        ),
        // 8 hari lagi (hijau)
        DeadlineItem(
          taskId: 't3',
          fileId: 'f2',
          fileTitle: 'Projek',
          fileRelativePath: 'f2.list',
          fileType: 'list',
          taskText: 'Deploy',
          at: DateTime(2026, 4, 18, 18, 0),
          done: false,
        ),
        // Overdue (merah)
        DeadlineItem(
          taskId: 't4',
          fileId: 'f3',
          fileTitle: 'Laporan',
          fileRelativePath: 'f3.list',
          fileType: 'list',
          taskText: 'Revisi',
          at: DateTime(2026, 4, 9, 8, 0),
          done: false,
        ),
        // Task SELESAI di tanggal 2 hari lagi -> TIDAK boleh dihitung
        DeadlineItem(
          taskId: 't5',
          fileId: 'f4',
          fileTitle: 'Selesai',
          fileRelativePath: 'f4.list',
          fileType: 'list',
          taskText: 'Sudah beres',
          at: DateTime(2026, 4, 12, 16, 0),
          done: true,
        ),
        // Tanggal yang HANYA memiliki task selesai -> tidak ada warna sama sekali
        DeadlineItem(
          taskId: 't6',
          fileId: 'f5',
          fileTitle: 'Lunas',
          fileRelativePath: 'f5.list',
          fileType: 'list',
          taskText: 'Bayar kasir',
          at: DateTime(2026, 4, 25, 12, 0),
          done: true,
        ),
      ];

      final cubit = DeadlineCalendarCubit(
        repository: repository,
        nowProvider: () => now,
      );

      await cubit.loadDeadlines();
      final state = cubit.state;

      // 2 hari: merah
      final d2 = DateTime(2026, 4, 12);
      expect(state.dateColors[d2], AppColors.deadlineUrgent);
      expect(state.dateDotColors[d2], AppColors.deadlineUrgent);

      // 5 hari: netral (tidak ada di dateColors, dot abu-abu)
      final d5 = DateTime(2026, 4, 15);
      expect(state.dateColors.containsKey(d5), isFalse);
      expect(state.dateDotColors[d5], const Color(0xFF9E9E9E));

      // 8 hari: hijau
      final d8 = DateTime(2026, 4, 18);
      expect(state.dateColors[d8], AppColors.deadlineRelaxed);
      expect(state.dateDotColors[d8], AppColors.deadlineRelaxed);

      // Overdue: merah
      final dOverdue = DateTime(2026, 4, 9);
      expect(state.dateColors[dOverdue], AppColors.deadlineUrgent);

      // Tanggal 25 April hanya memiliki task selesai -> tidak ada warna atau dot
      final dCompletedOnly = DateTime(2026, 4, 25);
      expect(state.dateColors.containsKey(dCompletedOnly), isFalse);
      expect(state.dateDotColors.containsKey(dCompletedOnly), isFalse);

      // Titik indikator lonceng: true karena ada deadline <= 3 hari
      expect(state.hasUrgentDeadline, isTrue);

      // upcomingDeadlines hanya memuat task belum selesai, urut terdekat
      expect(state.upcomingDeadlines.length, 4);
      expect(state.upcomingDeadlines.map((i) => i.taskId).toList(), [
        't4', // 9 Apr (overdue terdekat)
        't1', // 12 Apr
        't2', // 15 Apr
        't3', // 18 Apr
      ]);
    });

    test('prioritas warna bila ada beberapa task di tanggal sama: merah > netral > hijau', () async {
      repository.deadlines = [
        DeadlineItem(
          taskId: 't1',
          fileId: 'f1',
          fileTitle: 'Campur',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Tugas Santai',
          at: DateTime(2026, 4, 11, 10, 0), // < 3 hari -> urgent
          done: false,
        ),
        DeadlineItem(
          taskId: 't2',
          fileId: 'f1',
          fileTitle: 'Campur',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Tugas Lain',
          at: DateTime(2026, 4, 11, 15, 0),
          done: false,
        ),
      ];

      final cubit = DeadlineCalendarCubit(
        repository: repository,
        nowProvider: () => now,
      );

      await cubit.loadDeadlines();
      expect(cubit.state.dateColors[DateTime(2026, 4, 11)], AppColors.deadlineUrgent);
    });

    test('hasUrgentDeadline false bila hanya ada deadline > 3 hari', () async {
      repository.deadlines = [
        DeadlineItem(
          taskId: 't1',
          fileId: 'f1',
          fileTitle: 'Nanti',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Bulan Depan',
          at: DateTime(2026, 4, 20, 10, 0), // 10 hari lagi
          done: false,
        ),
      ];

      final cubit = DeadlineCalendarCubit(
        repository: repository,
        nowProvider: () => now,
      );

      await cubit.loadDeadlines();
      expect(cubit.state.hasUrgentDeadline, isFalse);
    });
  });

  group('DateSelectorStrip Visual & Interaction (PRD 7.1 Point 2 & 3)', () {
    testWidgets('chip terpilih tetap hitam; jika ada deadline ada dot di bawah angka', (tester) async {
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);

      final colors = {
        todayMidnight: AppColors.deadlineUrgent,
      };
      final dotColors = {
        todayMidnight: AppColors.deadlineUrgent,
      };

      DateTime? tappedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateSelectorStrip(
              selectedDate: todayMidnight,
              dateColors: colors,
              dateDotColors: dotColors,
              onDateSelected: (d) => tappedDate = d,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cari chip tanggal terpilih
      final chipFinder = find.byType(AnimatedContainer).first;
      final container = tester.widget<AnimatedContainer>(chipFinder);
      final decoration = container.decoration as BoxDecoration;

      // Chip terpilih tetap hitam (AppColors.dateChipActive)
      expect(decoration.color, AppColors.dateChipActive);

      // Titik dot berwarna muncul di bawah angka
      expect(find.byKey(const Key('selectedDateDot')), findsWidgets);

      // Tap chip memanggil callback
      await tester.tap(chipFinder);
      expect(tappedDate, isNotNull);
    });
  });

  group('NoteListBloc Date Filter Toggle (PRD 7.1 Point 3)', () {
    late FakeCalendarExplorerRepository repository;
    final targetDate = DateTime(2026, 4, 12);

    final matchingList = ListFile(
      id: 'list-1',
      relativePath: 'list-1.list',
      title: 'Tugas Target',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 'task-1',
          text: 'Kerjakan PR',
          done: false,
          deadline: DeadlineSettings(
            at: DateTime(2026, 4, 12, 15, 0),
            remindStartDaysBefore: 1,
            remindTimes: const ['09:00'],
          ),
        ),
      ],
    );

    final otherList = ListFile(
      id: 'list-2',
      relativePath: 'list-2.list',
      title: 'Tugas Lain',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 'task-2',
          text: 'Kerjakan Tugas Lain',
          done: false,
          deadline: DeadlineSettings(
            at: DateTime(2026, 4, 20, 15, 0),
            remindStartDaysBefore: 1,
            remindTimes: const ['09:00'],
          ),
        ),
      ],
    );

    setUp(() {
      repository = FakeCalendarExplorerRepository();
      repository.contents = [matchingList, otherList];
    });

    test('tap tanggal memfilter file; tap lagi pada tanggal yang sama melepas filter', () async {
      final bloc = NoteListBloc(repository: repository);

      // 1. Muat awal
      bloc.add(const LoadNotes());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<NoteListState>(
          (s) => s is NoteListLoaded && s.files.length == 2 && s.selectedDate == null,
        )),
      );

      // 2. Tap tanggal target -> memfilter ke 1 file yang sesuai
      bloc.add(SelectDateFilter(targetDate));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<NoteListState>(
          (s) =>
              s is NoteListLoaded &&
              s.selectedDate != null &&
              s.files.length == 1 &&
              s.files.first.id == 'list-1',
        )),
      );

      // 3. Tap LAGI pada tanggal yang sama -> filter dilepas (selectedDate == null, 2 files)
      bloc.add(SelectDateFilter(targetDate));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<NoteListState>(
          (s) =>
              s is NoteListLoaded &&
              s.selectedDate == null &&
              s.files.length == 2,
        )),
      );

      await bloc.close();
    });
  });

  group('Lonceng & RemindersPage (PRD 7.1 Point 4)', () {
    testWidgets('HomeHeader menampilkan titik hijau lonceng saat hasUrgentDeadline true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(
              onQueryChanged: (_) {},
              hasUrgentDeadline: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('bellUrgentDot')), findsOneWidget);
    });

    testWidgets('HomeHeader menyembunyikan titik hijau lonceng saat hasUrgentDeadline false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(
              onQueryChanged: (_) {},
              hasUrgentDeadline: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('bellUrgentDot')), findsNothing);
    });

    testWidgets('RemindersPage menampilkan daftar deadline urut terdekat dan sisa waktu', (tester) async {
      final repository = FakeCalendarExplorerRepository();
      final now = DateTime(2026, 4, 10, 10, 0);

      repository.deadlines = [
        DeadlineItem(
          taskId: 't1',
          fileId: 'f1',
          fileTitle: 'Catatan Belanja',
          fileRelativePath: 'f1.list',
          fileType: 'list',
          taskText: 'Beli Tomat',
          at: DateTime(2026, 4, 12, 10, 0),
          done: false,
        ),
      ];

      final cubit = DeadlineCalendarCubit(
        repository: repository,
        nowProvider: () => now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<DeadlineCalendarCubit>.value(
            value: cubit,
            child: RemindersPage(nowProvider: () => now),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pengingat'), findsOneWidget);
      expect(find.text('Beli Tomat'), findsOneWidget);
      expect(find.text('Catatan Belanja'), findsOneWidget);
      expect(find.text('Deadline tinggal 2 hari 0 jam'), findsOneWidget);
      expect(find.text('12 Apr, 10:00'), findsOneWidget);
    });
  });
}
