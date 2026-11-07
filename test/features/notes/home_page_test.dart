import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_state.dart';
import 'package:reminding/features/notes/presentation/pages/home_page.dart';
import 'package:reminding/features/notes/presentation/widgets/category_filter_chips.dart';
import 'package:reminding/features/notes/presentation/widgets/folder_tile.dart';
import 'package:reminding/features/notes/presentation/widgets/note_card.dart';
import 'package:reminding/features/notes/presentation/widgets/notes_empty_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('home_page_test_');
    tempSupportDir =
        await Directory.systemTemp.createTemp('home_page_support_test_');
    await initDependencies(
      overrideNotesDir: tempDir,
      overrideSupportDir: tempSupportDir,
    );
  });

  tearDown(() async {
    await sl.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  group('HomePage Responsive Column Count (PRD 12)', () {
    test('getColumnCount returns correct columns per breakpoint', () {
      expect(HomePage.getColumnCount(360), equals(2));
      expect(HomePage.getColumnCount(599), equals(2));
      expect(HomePage.getColumnCount(600), equals(3));
      expect(HomePage.getColumnCount(720), equals(3));
      expect(HomePage.getColumnCount(840), equals(3));
      expect(HomePage.getColumnCount(841), equals(4));
      expect(HomePage.getColumnCount(1200), equals(4));
    });
  });

  group('HomePage Widget Tests', () {
    testWidgets('displays empty state with PRD string when no items exist',
        (tester) async {
      final bloc = sl<NoteListBloc>()..add(const LoadNotes());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NoteListBloc>.value(
            value: bloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Belum ada catatan. Ketuk + untuk membuat.'),
        findsOneWidget,
      );
      expect(find.byType(NotesEmptyState), findsOneWidget);
    });

    testWidgets('displays filter chips for Semua, Favorit, Folder, List, Page',
        (tester) async {
      final bloc = sl<NoteListBloc>()..add(const LoadNotes());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NoteListBloc>.value(
            value: bloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EntryFilterChips), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Favorit'), findsOneWidget);
      expect(find.text('Folder'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Page'), findsOneWidget);

      // Tap on 'Folder' chip
      await tester.tap(find.text('Folder'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(bloc.state, isA<NoteListLoaded>());
      final loadedState = bloc.state as NoteListLoaded;
      expect(loadedState.currentFilter, equals(HomeFilter.folder));
    });

    testWidgets(
        'renders folder tiles and file cards with responsive layout and FAB',
        (tester) async {
      final repo = sl<ExplorerRepository>();
      final now = DateTime.now();

      await tester.runAsync(() async {
        // Seed 1 folder, 1 page file, 1 list file
        await repo.createFolder(parentRelativePath: '', name: 'Work Notes');
        await repo.savePage(PageFile(
          id: 'p1',
          relativePath: 'Project Proposal.json',
          title: 'Project Proposal',
          plainText: 'Discuss sprint goals and milestones.',
          colorIndex: 0,
          favoritedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
        await repo.saveList(ListFile(
          id: 'l1',
          relativePath: 'Sprint Tasks.json',
          title: 'Sprint Tasks',
          tasks: [
            Task(id: 't1', text: 'Task 1', done: true),
            Task(id: 't2', text: 'Task 2', done: false),
          ],
          colorIndex: 1,
          favoritedAt: null,
          createdAt: now,
          updatedAt: now,
        ));
      });

      final bloc = sl<NoteListBloc>()..add(const LoadNotes());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NoteListBloc>.value(
            value: bloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Folder tiles should exist
      expect(find.byType(FolderTile), findsOneWidget);
      expect(find.text('Work Notes'), findsOneWidget);

      // Note cards should exist
      expect(find.byType(NoteCard), findsNWidgets(2));
      expect(find.text('Project Proposal'), findsOneWidget);
      expect(find.text('Sprint Tasks'), findsOneWidget);
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

      // Verify FAB exists and has harmless callback (TODO M3)
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
    });
  });
}
