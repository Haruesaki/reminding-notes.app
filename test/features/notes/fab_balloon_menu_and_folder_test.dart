import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/pages/editor_placeholder_page.dart';
import 'package:reminding/features/notes/presentation/pages/home_page.dart';
import 'package:reminding/features/notes/presentation/widgets/balloon_fab_menu.dart';
import 'package:reminding/features/notes/presentation/widgets/date_selector_strip.dart';
import 'package:reminding/features/notes/presentation/widgets/folder_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('m3_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('m3_support_test_');
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

  group('M3 Balloon FAB Menu Widget Tests (PRD 4.4, 7.3)', () {
    testWidgets(
        'tap FAB opens 3 balloon pills (Folder, List, Page) with icons and labels',
        (tester) async {
      bool folderSelected = false;
      bool listSelected = false;
      bool pageSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Content')),
                BalloonFabMenu(
                  onSelectFolder: () => folderSelected = true,
                  onSelectList: () => listSelected = true,
                  onSelectPage: () => pageSelected = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Initially closed
      expect(find.text('Folder'), findsNothing);
      expect(find.text('List'), findsNothing);
      expect(find.text('Page'), findsNothing);

      // Tap FAB to open
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check all 3 pills with icons and text
      expect(find.text('Folder'), findsOneWidget);
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);

      expect(find.text('List'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);

      expect(find.text('Page'), findsOneWidget);
      expect(find.byIcon(Icons.description_rounded), findsOneWidget);

      // Tap Folder pill
      await tester.tap(find.text('Folder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(folderSelected, isTrue);
      expect(listSelected, isFalse);
      expect(pageSelected, isFalse);
    });

    testWidgets('dismisses menu when tapping scrim backdrop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BalloonFabMenu(
                  onSelectFolder: () {},
                  onSelectList: () {},
                  onSelectPage: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Folder'), findsOneWidget);

      // Tap on top-left area (scrim)
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now closed
      expect(find.text('Folder'), findsNothing);
      expect(find.text('List'), findsNothing);
      expect(find.text('Page'), findsNothing);
    });

    testWidgets('dismisses menu when tapping FAB again (close button)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BalloonFabMenu(
                  onSelectFolder: () {},
                  onSelectList: () {},
                  onSelectPage: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Tap FAB to open
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Page'), findsOneWidget);

      // Tap FAB again to close
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Page'), findsNothing);
    });
  });

  group('M3 Folder Dialog & Creation (PRD 7.3)', () {
    testWidgets(
        'creating folder via dialog creates folder and displays it as tile',
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

      // Open Balloon menu
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 'Folder' in Balloon menu
      await tester.tap(
        find.descendant(
          of: find.byType(BalloonFabMenu),
          matching: find.text('Folder'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog opens
      expect(find.text('Folder Baru'), findsOneWidget);
      expect(find.text('Buat'), findsOneWidget);

      // Empty validation: tap Buat without typing
      await tester.tap(find.text('Buat'));
      await tester.pump();
      expect(find.text('Nama folder tidak boleh kosong'), findsOneWidget);

      // Enter name and submit
      await tester.enterText(find.byType(TextFormField), 'Kuliah');
      await tester.tap(find.text('Buat'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Dialog closed, folder tile appears
      expect(find.text('Folder Baru'), findsNothing);
      expect(find.byType(FolderTile), findsOneWidget);
      expect(find.text('Kuliah'), findsOneWidget);
    });
  });

  group('M3 Placeholder Editor & Save Logic (PRD 7.4)', () {
    testWidgets('EditorPlaceholderPage does not save if title and content are empty',
        (tester) async {
      final repo = sl<ExplorerRepository>();

      await tester.pumpWidget(
        const MaterialApp(
          home: EditorPlaceholderPage(fileType: 'Page'),
        ),
      );
      await tester.pump();

      expect(find.text('Page Editor'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(milliseconds: 50));

      // Check no file created in disk
      final entries = await repo.getFolderContents('');
      final files = entries.whereType<FileEntry>().toList();
      expect(files.isEmpty, isTrue);
    });

    testWidgets('EditorPlaceholderPage saves file if content is non-empty',
        (tester) async {
      final repo = sl<ExplorerRepository>();

      await tester.pumpWidget(
        const MaterialApp(
          home: EditorPlaceholderPage(fileType: 'List'),
        ),
      );
      await tester.pump();

      // Enter content
      await tester.enterText(find.byType(TextField).at(0), 'Belanja Mingguan');
      await tester.enterText(find.byType(TextField).at(1), 'Telur\nSusu\nRoti');

      // Tap Simpan
      await tester.runAsync(() async {
        await tester.tap(find.text('Simpan'));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verify file created
      List<NodeEntry> entries = [];
      await tester.runAsync(() async {
        entries = await repo.getFolderContents('');
      });
      final files = entries.whereType<FileEntry>().toList();
      expect(files.length, equals(1));
      expect(files.first.title, equals('Belanja Mingguan'));
    });
  });

  group('M3 Nested Folder Navigation 3 Levels (PRD 7.2)', () {
    testWidgets(
        'navigates root -> Level1 -> Level2 -> Level3 with breadcrumbs, no date strip, back arrow',
        (tester) async {
      final repo = sl<ExplorerRepository>();

      // Pre-seed 3 nested folders:
      // Root / Level1
      // Root / Level1 / Level2
      // Root / Level1 / Level2 / Level3
      await repo.createFolder(parentRelativePath: '', name: 'Level1');
      await repo.createFolder(parentRelativePath: 'Level1', name: 'Level2');
      await repo.createFolder(
          parentRelativePath: 'Level1/Level2', name: 'Level3');

      final rootBloc = sl<NoteListBloc>()..add(const LoadNotes());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NoteListBloc>.value(
            value: rootBloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      // In Root:
      // - Date strip is present
      // - Burger button is present (no back button)
      // - Level1 folder tile is visible
      expect(find.byType(DateSelectorStrip), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.text('Level1'), findsOneWidget);

      // --- 1. Navigate to Level 1 ---
      await tester.runAsync(() async {
        await tester.tap(find.text('Level1'));
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      // In Level 1:
      // - Date strip is NOT present
      // - Back button replaces burger button
      // - Folder title 'Level1' and breadcrumb 'Level1' are displayed
      // - Level2 folder tile is visible
      expect(find.byType(DateSelectorStrip), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('Level2'), findsOneWidget);

      // --- 2. Navigate to Level 2 ---
      await tester.runAsync(() async {
        await tester.tap(find.text('Level2'));
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      // In Level 2:
      // - Title 'Level2', breadcrumb 'Level1 / Level2'
      // - Level3 folder tile is visible
      expect(find.text('Level1 / Level2'), findsOneWidget);
      expect(find.text('Level3'), findsOneWidget);

      // --- 3. Navigate to Level 3 ---
      await tester.runAsync(() async {
        await tester.tap(find.text('Level3'));
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      // In Level 3 (3rd level deep):
      // - Title 'Level3', breadcrumb 'Level1 / Level2 / Level3'
      // - Empty state (no further nested folders)
      expect(find.text('Level1 / Level2 / Level3'), findsOneWidget);
      expect(find.text('Level3'), findsOneWidget);

      // --- 4. Back navigation: Level 3 -> Level 2 ---
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(find.text('Level1 / Level2'), findsOneWidget);

      // --- 5. Back navigation: Level 2 -> Level 1 ---
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(find.text('Level2'), findsOneWidget);

      // --- 6. Back navigation: Level 1 -> Root ---
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      // Back to Root: DateSelectorStrip and Burger icon return
      expect(find.byType(DateSelectorStrip), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Level1'), findsOneWidget);
    });
  });
}
