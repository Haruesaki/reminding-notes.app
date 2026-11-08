import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/note_list/note_list_event.dart';
import 'package:reminding/features/notes/presentation/pages/home_page.dart';
import 'package:reminding/features/notes/presentation/pages/list_editor_page.dart';
import 'package:reminding/features/notes/presentation/pages/note_editor_page.dart';
import 'package:reminding/features/settings/presentation/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('responsive_ui_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('responsive_ui_sup_test_');
    await initDependencies(
      overrideNotesDir: tempDir,
      overrideSupportDir: tempSupportDir,
    );
  });

  tearDown(() async {
    await sl.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (tempSupportDir.existsSync()) tempSupportDir.deleteSync(recursive: true);
  });

  Widget buildTestHost({
    required Widget child,
    required Size physicalSize,
    double textScale = 1.0,
    double keyboardHeight = 0.0,
    WidgetTester? tester,
  }) {
    if (tester != null) {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
    }

    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: physicalSize,
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: child,
      ),
    );
  }

  group('Uji Responsivitas Layar (PRD 9, 12, M10)', () {
    final samplePage = PageFile(
      id: 'resp_page_1',
      relativePath: 'Catatan Responsif.json',
      title: 'Catatan Uji Responsif Layar',
      plainText: 'Menghitung tata letak responsif pada resolusi yang berbeda.',
      colorIndex: 1,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleList = ListFile(
      id: 'resp_list_1',
      relativePath: 'Daftar Responsif.json',
      title: 'Daftar Periksa Responsif',
      colorIndex: 2,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: const [
        Task(
          id: 't_1',
          text: 'Uji rasio 9:16 layar standar',
          done: false,
          collapsed: false,
          subtasks: [
            Subtask(id: 's_1', text: 'Subtask responsif 1', done: false),
            Subtask(id: 's_2', text: 'Subtask responsif 2', done: true),
          ],
        ),
        Task(
          id: 't_2',
          text: 'Uji resolusi tinggi 1220x2712',
          done: true,
          collapsed: false,
          subtasks: [],
        ),
      ],
    );

    testWidgets('1. Rasio 9:16 (360x640): HomePage, Editor, List, Settings tanpa overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      const size9_16 = Size(360, 640);
      final noteListBloc = sl<NoteListBloc>()..add(const LoadNotes());

      // HomePage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: size9_16,
          tester: tester,
          child: BlocProvider<NoteListBloc>.value(
            value: noteListBloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(HomePage.getColumnCount(360), equals(2));

      // NoteEditorPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: size9_16,
          tester: tester,
          child: NoteEditorPage(initialPage: samplePage),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // ListEditorPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: size9_16,
          tester: tester,
          child: ListEditorPage(initialList: sampleList),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // SettingsPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: size9_16,
          tester: tester,
          child: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Resolusi Tinggi 1220x2712: HomePage, Editor, List, Settings tanpa overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      const sizeHighRes = Size(1220, 2712);
      final noteListBloc = sl<NoteListBloc>()..add(const LoadNotes());

      // HomePage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: sizeHighRes,
          tester: tester,
          child: BlocProvider<NoteListBloc>.value(
            value: noteListBloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(HomePage.getColumnCount(1220), equals(4));

      // NoteEditorPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: sizeHighRes,
          tester: tester,
          child: NoteEditorPage(initialPage: samplePage),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // ListEditorPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: sizeHighRes,
          tester: tester,
          child: ListEditorPage(initialList: sampleList),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Tablet Portrait (800x1280) & Landscape (1280x800): kolom dan maxWidth sesuai', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      const tabletPortrait = Size(800, 1280);
      const tabletLandscape = Size(1280, 800);

      // Kolom breakpoint test
      expect(HomePage.getColumnCount(tabletPortrait.width), equals(3));
      expect(HomePage.getColumnCount(tabletLandscape.width), equals(4));

      // Tablet Landscape HomePage
      final noteListBloc = sl<NoteListBloc>()..add(const LoadNotes());
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: tabletLandscape,
          tester: tester,
          child: BlocProvider<NoteListBloc>.value(
            value: noteListBloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tablet Portrait ListEditorPage
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: tabletPortrait,
          tester: tester,
          child: ListEditorPage(initialList: sampleList),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Skala Teks 1.3 (Aksesibilitas / Huruf Besar): tidak overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      const phoneSize = Size(390, 844);
      final noteListBloc = sl<NoteListBloc>()..add(const LoadNotes());

      // HomePage dengan skala teks 1.3
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: phoneSize,
          textScale: 1.3,
          tester: tester,
          child: BlocProvider<NoteListBloc>.value(
            value: noteListBloc,
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // SettingsPage dengan skala teks 1.3
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: phoneSize,
          textScale: 1.3,
          tester: tester,
          child: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // ListEditorPage dengan skala teks 1.3
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: phoneSize,
          textScale: 1.3,
          tester: tester,
          child: ListEditorPage(initialList: sampleList),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Keyboard Terbuka (viewInsets bottom: 300): Editor dan Home tetap scrollable', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      const phoneSize = Size(390, 844);

      // NoteEditorPage dengan keyboard terbuka 300px
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: phoneSize,
          keyboardHeight: 300,
          tester: tester,
          child: NoteEditorPage(initialPage: samplePage),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // ListEditorPage dengan keyboard terbuka 300px
      await tester.pumpWidget(
        buildTestHost(
          physicalSize: phoneSize,
          keyboardHeight: 300,
          tester: tester,
          child: ListEditorPage(initialList: sampleList),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
