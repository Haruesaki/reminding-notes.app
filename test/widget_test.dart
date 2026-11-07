import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/app.dart';
import 'package:reminding/core/database/app_database.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    final db = await AppDatabase.initDatabase(
      factory: databaseFactoryFfi,
      overridePath: inMemoryDatabasePath,
    );
    await initDependencies(overrideDb: db);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('RemindingApp boots and displays Home screen components', (tester) async {
    await tester.pumpWidget(const RemindingApp());
    await tester.pump();

    // Allow SQLite FFI async query to complete on real async event loop
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Verify Greeting
    expect(find.text('Hi, Andrea 👋'), findsOneWidget);

    // Verify Search bar
    expect(find.text('Search notes...'), findsOneWidget);

    // Verify Filter Chip
    expect(find.text('All Notes'), findsOneWidget);

    // Verify Empty State when no notes exist
    expect(find.text('No notes here'), findsOneWidget);

    // Verify FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

