import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/notes/presentation/pages/note_editor_page.dart';
import 'package:reminding/features/notes/presentation/widgets/formatting_toolbar.dart';

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
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  testWidgets('NoteEditorPage renders title, content, toolbar and supports formatting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteEditorPage(noteId: 'new'),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify Title and Content placeholders
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Start typing...'), findsOneWidget);

    // Verify FormattingToolbar is present
    expect(find.byType(FormattingToolbar), findsOneWidget);

    // Enter Title
    await tester.enterText(find.byType(TextField).first, 'Meeting Notes');
    await tester.pump();

    // Enter Content
    await tester.enterText(find.byType(TextField).last, 'Discuss PRD and Figma');
    await tester.pump();

    // Tap Bold formatting action
    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    // Verify words count is displayed
    expect(find.textContaining('words'), findsOneWidget);
  });
}
