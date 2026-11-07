import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/app.dart';
import 'package:reminding/core/di/injection_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('widget_support_test_');
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

  testWidgets('RemindingApp boots and displays Home screen components', (tester) async {
    await tester.pumpWidget(const RemindingApp());
    await tester.pump();

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Search bar
    expect(find.text('Search notes...'), findsOneWidget);

    // Verify Filter Chips from HomeFilter
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Favorit'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Page'), findsOneWidget);

    // Verify Empty State when no notes exist
    expect(
      find.text('Belum ada catatan. Ketuk + untuk membuat.'),
      findsOneWidget,
    );

    // Verify FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

