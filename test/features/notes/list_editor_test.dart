import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/presentation/pages/list_editor_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('list_editor_test_');
    tempSupportDir =
        await Directory.systemTemp.createTemp('list_editor_support_test_');
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

  testWidgets(
      'aturan centang: induk centang semua subtask, semua subtask centang induk, uncheck subtask uncheck induk',
      (tester) async {
    final initialList = ListFile(
      id: 'list_test_1',
      relativePath: 'list_test_1.json',
      title: 'Daftar Pekerjaan',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 'task_1',
          text: 'Induk',
          done: false,
          collapsed: false,
          subtasks: [
            Subtask(id: 'sub_1', text: 'Sub 1', done: false),
            Subtask(id: 'sub_2', text: 'Sub 2', done: false),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListEditorPage(initialList: initialList),
      ),
    );
    await tester.pumpAndSettle();

    final parentCheckboxFinder =
        find.byKey(const Key('task_checkbox_task_1'));
    final sub1CheckboxFinder =
        find.byKey(const Key('subtask_checkbox_sub_1'));
    final sub2CheckboxFinder =
        find.byKey(const Key('subtask_checkbox_sub_2'));

    expect(parentCheckboxFinder, findsOneWidget);
    expect(sub1CheckboxFinder, findsOneWidget);
    expect(sub2CheckboxFinder, findsOneWidget);

    Checkbox parentCheckbox = tester.widget(parentCheckboxFinder);
    Checkbox sub1Checkbox = tester.widget(sub1CheckboxFinder);
    Checkbox sub2Checkbox = tester.widget(sub2CheckboxFinder);

    expect(parentCheckbox.value, isFalse);
    expect(sub1Checkbox.value, isFalse);
    expect(sub2Checkbox.value, isFalse);

    // 1. Centang induk -> semua sub task tercentang
    await tester.tap(parentCheckboxFinder);
    await tester.pumpAndSettle();

    parentCheckbox = tester.widget(parentCheckboxFinder);
    sub1Checkbox = tester.widget(sub1CheckboxFinder);
    sub2Checkbox = tester.widget(sub2CheckboxFinder);

    expect(parentCheckbox.value, isTrue);
    expect(sub1Checkbox.value, isTrue);
    expect(sub2Checkbox.value, isTrue);

    // 2. Hilangkan centang satu sub task -> induk tidak tercentang
    await tester.tap(sub1CheckboxFinder);
    await tester.pumpAndSettle();

    parentCheckbox = tester.widget(parentCheckboxFinder);
    sub1Checkbox = tester.widget(sub1CheckboxFinder);
    sub2Checkbox = tester.widget(sub2CheckboxFinder);

    expect(parentCheckbox.value, isFalse);
    expect(sub1Checkbox.value, isFalse);
    expect(sub2Checkbox.value, isTrue);

    // 3. Semua sub task tercentang -> induk tercentang
    await tester.tap(sub1CheckboxFinder);
    await tester.pumpAndSettle();

    parentCheckbox = tester.widget(parentCheckboxFinder);
    sub1Checkbox = tester.widget(sub1CheckboxFinder);
    sub2Checkbox = tester.widget(sub2CheckboxFinder);

    expect(parentCheckbox.value, isTrue);
    expect(sub1Checkbox.value, isTrue);
    expect(sub2Checkbox.value, isTrue);
  });

  testWidgets(
      'sub task: penambahan via menu, chevron buka/tutup, dan menu hanya berisi hapus',
      (tester) async {
    final initialList = ListFile(
      id: 'list_test_2',
      relativePath: 'list_test_2.json',
      title: 'Test Subtask',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 'task_only',
          text: 'Tugas Tanpa Anak',
          done: false,
          collapsed: false,
          subtasks: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListEditorPage(initialList: initialList),
      ),
    );
    await tester.pumpAndSettle();

    // Chevron TIDAK boleh tampil jika task tidak punya sub task
    expect(
        find.byKey(const Key('task_chevron_task_only')), findsNothing);

    // Buka menu titik tiga pada task
    final menuFinder = find.byKey(const Key('task_menu_task_only'));
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    // Menu berisi "Tambahkan sub task"
    final addSubtaskFinder = find.text('Tambahkan sub task');
    expect(addSubtaskFinder, findsOneWidget);
    await tester.tap(addSubtaskFinder);
    await tester.pumpAndSettle();

    // Sekarang chevron tampil
    final chevronFinder =
        find.byKey(const Key('task_chevron_task_only'));
    expect(chevronFinder, findsOneWidget);

    // Subtask text field muncul
    expect(find.byType(TextField), findsNWidgets(3)); // title, task, subtask

    // Menu pada sub task HANYA berisi Hapus
    final subMenuFinder = find.byType(PopupMenuButton<String>).last;
    await tester.tap(subMenuFinder);
    await tester.pumpAndSettle();

    expect(find.text('Hapus'), findsOneWidget);
    expect(find.text('Tambahkan sub task'), findsNothing);
    expect(find.text('Pengaturan'), findsNothing);

    // Tutup menu dengan tap latar
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Toggle chevron untuk collapse subtask
    await tester.tap(chevronFinder);
    await tester.pumpAndSettle();

    // Subtask tersembunyi
    expect(find.byType(TextField), findsNWidgets(2)); // title and task only
  });

  testWidgets('hapus task memunculkan snackbar Urungkan dan dapat dikembalikan',
      (tester) async {
    final initialList = ListFile(
      id: 'list_test_3',
      relativePath: 'list_test_3.json',
      title: 'Test Hapus',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 'task_to_delete',
          text: 'Tugas yang akan dihapus',
          done: false,
          collapsed: false,
          subtasks: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListEditorPage(initialList: initialList),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tugas yang akan dihapus'), findsOneWidget);

    // Hapus via menu titik tiga
    final menuFinder = find.byKey(const Key('task_menu_task_to_delete'));
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    final deleteOption = find.text('Hapus');
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // Task hilang dari layar
    expect(find.text('Tugas yang akan dihapus'), findsNothing);

    // Snackbar dengan tombol Urungkan muncul
    expect(find.text('Tugas dihapus'), findsOneWidget);
    final undoBtn = find.text('Urungkan');
    expect(undoBtn, findsOneWidget);

    // Tap Urungkan
    await tester.tap(undoBtn);
    await tester.pumpAndSettle();

    // Task kembali
    expect(find.text('Tugas yang akan dihapus'), findsOneWidget);
  });

  testWidgets('file kosong tidak tersimpan saat keluar (PRD 6.5, 7.5)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ListEditorPage(noteId: 'new'),
      ),
    );
    await tester.pumpAndSettle();

    // Tap back button
    final backBtn = find.byKey(const Key('editor_back_button'));
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    final files = tempDir
        .listSync()
        .where((e) =>
            e.path.endsWith('.json') && !e.path.contains('_folder.json'))
        .toList();
    expect(files, isEmpty);
  });

  testWidgets('persistensi: list tersimpan ke disk dan memuat kembali tasks',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ListEditorPage(noteId: 'new'),
      ),
    );
    await tester.pumpAndSettle();

    // Masukkan judul
    final titleField = find.byKey(const Key('list_title_input'));
    await tester.enterText(titleField, 'Rencana Belanja');
    await tester.pump();

    // Tambah task
    final addTaskBtn = find.byKey(const Key('add_task_button'));
    await tester.tap(addTaskBtn);
    await tester.pump();

    // Isi teks task
    final taskTextField = find.byType(TextField).last;
    await tester.enterText(taskTextField, 'Beli Buah');
    await tester.pump();

    // Tap back untuk keluar dan simpan
    final backBtn = find.byKey(const Key('editor_back_button'));
    await tester.tap(backBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Periksa file tersimpan di disk
    final files = tempDir
        .listSync()
        .where((e) =>
            e.path.endsWith('.json') && !e.path.contains('_folder.json'))
        .toList();
    expect(files.length, 1);

    final fileContent =
        jsonDecode(File(files.first.path).readAsStringSync()) as Map<String, dynamic>;
    expect(fileContent['title'], 'Rencana Belanja');
    expect(fileContent['type'], 'list');
    final tasksJson = fileContent['tasks'] as List<dynamic>;
    expect(tasksJson.length, 1);
    expect(tasksJson.first['text'], 'Beli Buah');
  });

  testWidgets('clipboard copy menyalin teks dalam format [ ] dan [x]',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        return null;
      },
    );

    final initialList = ListFile(
      id: 'list_copy_test',
      relativePath: 'list_copy_test.json',
      title: 'Target Harian',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 't1',
          text: 'Bangun pagi',
          done: true,
          collapsed: false,
          subtasks: [
            Subtask(id: 's1', text: 'Minum air', done: true),
            Subtask(id: 's2', text: 'Olahraga', done: false),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListEditorPage(initialList: initialList),
      ),
    );
    await tester.pumpAndSettle();

    final copyBtn = find.byKey(const Key('editor_copy_button'));
    await tester.tap(copyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verifikasi snackbar Disalin muncul
    expect(find.text('Disalin'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('lencana deadline menampilkan badge pada item task', (tester) async {
    final deadlineTime = DateTime.now().add(const Duration(days: 1));
    final initialList = ListFile(
      id: 'list_deadline_badge',
      relativePath: 'list_deadline_badge.json',
      title: 'Target Deadline',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        Task(
          id: 't_dl',
          text: 'Kerjakan Tugas KP',
          done: false,
          deadline: DeadlineSettings(
            at: deadlineTime,
            remindStartDaysBefore: 1,
            remindTimes: const ['09:00'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListEditorPage(initialList: initialList),
      ),
    );
    await tester.pumpAndSettle();

    final badgeFinder = find.byKey(const Key('deadline_badge_t_dl'));
    expect(badgeFinder, findsOneWidget);
  });
}
