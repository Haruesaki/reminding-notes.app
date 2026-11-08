import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/cubit/copy_move_cubit.dart';
import 'package:reminding/features/notes/presentation/cubit/deadline_calendar_cubit.dart';
import 'package:reminding/features/notes/presentation/pages/home_page.dart';
import 'package:reminding/features/settings/presentation/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempNotesDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempNotesDir = await Directory.systemTemp.createTemp('settings_notes_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('settings_support_test_');
    await initDependencies(
      overrideNotesDir: tempNotesDir,
      overrideSupportDir: tempSupportDir,
    );
  });

  tearDown(() async {
    await sl.reset();
    if (tempNotesDir.existsSync()) {
      try {
        tempNotesDir.deleteSync(recursive: true);
      } catch (_) {}
    }
    if (tempSupportDir.existsSync()) {
      try {
        tempSupportDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Widget buildHomePage() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NoteListBloc>(
          create: (_) => sl<NoteListBloc>()..add(const LoadNotes()),
        ),
        BlocProvider<DeadlineCalendarCubit>(
          create: (_) => sl<DeadlineCalendarCubit>(),
        ),
        BlocProvider<CopyMoveCubit>.value(
          value: sl<CopyMoveCubit>(),
        ),
      ],
      child: const MaterialApp(
        home: HomePage(),
      ),
    );
  }

  Widget buildSettingsPage() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NoteListBloc>(
          create: (_) => sl<NoteListBloc>(),
        ),
      ],
      child: const MaterialApp(
        home: SettingsPage(),
      ),
    );
  }

  group('M9 - Burger & Navigation Drawer', () {
    testWidgets('Burger di kiri search bar membuka drawer dari kiri dengan satu menu: Pengaturan (ikon gear)', (tester) async {
      await tester.pumpWidget(buildHomePage());
      await tester.pumpAndSettle();

      // Pastikan menu icon burger ada
      final burgerFinder = find.byIcon(Icons.menu);
      expect(burgerFinder, findsOneWidget);

      // Drawer belum terbuka
      expect(find.text('Pengaturan'), findsNothing);

      // Klik burger icon
      await tester.tap(burgerFinder);
      await tester.pumpAndSettle();

      // Drawer terbuka: menampilkan judul 'Notes' dan menu 'Pengaturan' dengan ikon gear
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });

  group('M9 - Halaman Pengaturan (SettingsPage)', () {
    testWidgets('Tampilkan accordion Backup, teks bantu uninstall, dan chevron berputar 200ms', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      await tester.pumpAndSettle();

      // 1. Tampilkan judul Pengaturan dan item Backup
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Backup'), findsOneWidget);
      expect(find.byIcon(Icons.backup_outlined), findsOneWidget);

      // 2. Tampilkan teks bantu bahwa data terhapus bila di-uninstall
      expect(
        find.textContaining('Data terhapus bila aplikasi di-uninstall'),
        findsOneWidget,
      );

      // 3. Sebelum dibuka: Export dan Import belum tampil
      expect(find.text('Export'), findsNothing);
      expect(find.text('Import'), findsNothing);

      // Cek AnimatedRotation awal bernilai 0.0
      final rotationFinder = find.byType(AnimatedRotation);
      expect(rotationFinder, findsOneWidget);
      AnimatedRotation rotationWidget = tester.widget<AnimatedRotation>(rotationFinder);
      expect(rotationWidget.turns, equals(0.0));
      expect(rotationWidget.duration, equals(const Duration(milliseconds: 200)));

      // 4. Buka accordion Backup
      await tester.tap(find.text('Backup'));
      // Animasi berlangsung 200ms
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Cek rotasi menjadi 0.25 (chevron menghadap ke bawah 'v')
      rotationWidget = tester.widget<AnimatedRotation>(rotationFinder);
      expect(rotationWidget.turns, equals(0.25));

      // 5. Menampilkan pilihan Export dan Import dengan ikon
      expect(find.text('Export'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      // 6. Tutup kembali accordion
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();

      rotationWidget = tester.widget<AnimatedRotation>(rotationFinder);
      expect(rotationWidget.turns, equals(0.0));
      expect(find.text('Export'), findsNothing);
      expect(find.text('Import'), findsNothing);
    });
  });
}
