import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/data/datasources/local_storage_data_source.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/presentation/pages/note_editor_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('note_editor_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('note_editor_support_test_');
    await initDependencies(
      overrideNotesDir: tempDir,
      overrideSupportDir: tempSupportDir,
    );
  });

  tearDown(() async {
    await sl.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    if (tempSupportDir.existsSync()) {
      tempSupportDir.deleteSync(recursive: true);
    }
  });

  testWidgets('file kosong tidak tersimpan saat keluar (PRD 7.4)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorPage(noteId: 'new'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap back button
    final backBtn = find.byKey(const Key('editor_back_button'));
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final files = tempDir
        .listSync()
        .where((e) => e.path.endsWith('.json') && !e.path.contains('_folder.json'))
        .toList();
    expect(files, isEmpty);
  });

  testWidgets('favorit tersimpan saat di-toggle di editor', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorPage(noteId: 'new'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Enter title so it will be saved
    final titleField = find.byKey(const Key('note_title_input'));
    await tester.enterText(titleField, 'Catatan Penting');
    await tester.pump();

    // Toggle favorite
    final favBtn = find.byKey(const Key('editor_favorite_button'));
    expect(favBtn, findsOneWidget);
    await tester.tap(favBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // Heart animation

    // Exit to trigger save
    final backBtn = find.byKey(const Key('editor_back_button'));
    await tester.tap(backBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify file on disk has isFavorite = true
    final dataSource = sl<LocalStorageDataSource>();
    final entries = await dataSource.listFolder('');
    final files = entries.whereType<PageFile>().toList();
    expect(files.length, 1);
    expect(files.first.title, 'Catatan Penting');
    expect(files.first.isFavorite, isTrue);
  });

  testWidgets('format bertahan setelah tutup-buka editor', (tester) async {
    final dataSource = sl<LocalStorageDataSource>();
    final initialDelta = [
      {
        'insert': 'Teks Tebal',
        'attributes': {'bold': true}
      },
      {'insert': '\nTeks Normal\n'}
    ];
    final page = PageFile(
      id: 'page_formatted_1',
      schemaVersion: 1,
      title: 'Formatted Note',
      relativePath: 'Formatted Note.json',
      colorIndex: 0,
      favoritedAt: null,
      content: initialDelta,
      plainText: 'Teks Tebal\nTeks Normal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final written = await tester.runAsync(() => dataSource.writePage(page));

    // Open in NoteEditorPage
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorPage(noteId: 'page_formatted_1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Check title loaded
    expect(find.text('Formatted Note'), findsOneWidget);

    // Verify QuillEditor is rendered
    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);

    // Exit editor
    final backBtn = find.byKey(const Key('editor_back_button'));
    await tester.tap(backBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Read back from disk to verify Delta content remained intact
    final reloaded = await tester.runAsync(() => dataSource.readPage(written!.relativePath));
    expect(reloaded!.title, 'Formatted Note');
    expect(reloaded.content, isNotEmpty);
    final boldOp = reloaded.content.firstWhere(
      (op) => op['insert'] == 'Teks Tebal',
      orElse: () => {},
    );
    expect(boldOp['attributes'], isNotNull);
    expect(boldOp['attributes']['bold'], isTrue);
  });

  testWidgets('ganti judul mengganti nama file di disk (PRD 6.3)', (tester) async {
    final dataSource = sl<LocalStorageDataSource>();
    final page = PageFile(
      id: 'page_rename_test',
      schemaVersion: 1,
      title: 'Judul Awal',
      relativePath: 'Judul Awal.json',
      colorIndex: 0,
      favoritedAt: null,
      content: [
        {'insert': 'Isi catatan\n'}
      ],
      plainText: 'Isi catatan',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final written = await tester.runAsync(() => dataSource.writePage(page));

    // Verify initial file exists
    final initialFile = File('${tempDir.path}/${written!.relativePath}');
    expect(initialFile.existsSync(), isTrue);

    // Open in NoteEditorPage
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorPage(noteId: 'page_rename_test'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Change title to "Judul Baru"
    final titleField = find.byKey(const Key('note_title_input'));
    await tester.enterText(titleField, 'Judul Baru');
    await tester.pump();

    // Exit editor to save
    final backBtn = find.byKey(const Key('editor_back_button'));
    await tester.tap(backBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Old file should no longer exist
    expect(initialFile.existsSync(), isFalse);

    // New file with sanitized title should exist
    final newFile = File('${tempDir.path}/Judul Baru.json');
    expect(newFile.existsSync(), isTrue);

    // Verify content inside new file
    final newContent = jsonDecode(newFile.readAsStringSync());
    expect(newContent['title'], 'Judul Baru');
    expect(newContent['plainText'], 'Isi catatan');
  });
}
