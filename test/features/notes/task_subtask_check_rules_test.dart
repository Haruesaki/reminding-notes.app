import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/di/injection_container.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'package:reminding/features/notes/presentation/bloc/list_editor/list_editor_bloc.dart';
import 'package:reminding/features/notes/presentation/bloc/list_editor/list_editor_event.dart';
import 'package:reminding/features/notes/presentation/bloc/list_editor/list_editor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory tempSupportDir;
  late ListEditorBloc bloc;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('check_rules_test_');
    tempSupportDir = await Directory.systemTemp.createTemp('check_rules_sup_test_');
    await initDependencies(
      overrideNotesDir: tempDir,
      overrideSupportDir: tempSupportDir,
    );
    bloc = ListEditorBloc(repository: sl<ExplorerRepository>());
  });

  tearDown(() async {
    await bloc.close();
    await sl.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (tempSupportDir.existsSync()) tempSupportDir.deleteSync(recursive: true);
  });

  group('PRD 13.1 & PRD 7.1: Aturan Centang Induk / Sub Task', () {
    final sampleList = ListFile(
      id: 'list_test_rules',
      relativePath: 'list_test_rules.json',
      title: 'Daftar Pekerjaan Proyek',
      colorIndex: 0,
      favoritedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: const [
        Task(
          id: 'parent_1',
          text: 'Tugas Utama 1',
          done: false,
          collapsed: false,
          subtasks: [
            Subtask(id: 'sub_1', text: 'Sub 1', done: false),
            Subtask(id: 'sub_2', text: 'Sub 2', done: false),
          ],
        ),
        Task(
          id: 'parent_2',
          text: 'Tugas Mandiri (Tanpa Subtask)',
          done: false,
          collapsed: false,
          subtasks: [],
        ),
      ],
    );

    test('1. Centang task induk -> semua sub task ikut tercentang', () async {
      bloc.add(InitializeList(initialList: sampleList));
      await expectLater(
        bloc.stream,
        emitsThrough(isA<ListEditorLoaded>()),
      );

      // Centang induk
      bloc.add(const ToggleListTaskDone('parent_1'));

      final nextState = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      final task = nextState.listFile.tasks.firstWhere((t) => t.id == 'parent_1');

      expect(task.done, isTrue);
      expect(task.subtasks.every((s) => s.done), isTrue);
    });

    test('2. Uncheck task induk -> semua sub task ikut tidak tercentang', () async {
      final allDoneList = sampleList.copyWith(
        tasks: [
          const Task(
            id: 'parent_1',
            text: 'Tugas Utama 1',
            done: true,
            collapsed: false,
            subtasks: [
              Subtask(id: 'sub_1', text: 'Sub 1', done: true),
              Subtask(id: 'sub_2', text: 'Sub 2', done: true),
            ],
          ),
        ],
      );

      bloc.add(InitializeList(initialList: allDoneList));
      await expectLater(
        bloc.stream,
        emitsThrough(isA<ListEditorLoaded>()),
      );

      // Hilangkan centang induk
      bloc.add(const ToggleListTaskDone('parent_1'));

      final nextState = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      final task = nextState.listFile.tasks.firstWhere((t) => t.id == 'parent_1');

      expect(task.done, isFalse);
      expect(task.subtasks.every((s) => !s.done), isTrue);
    });

    test('3. Semua sub task tercentang -> induk otomatis tercentang', () async {
      bloc.add(InitializeList(initialList: sampleList));
      await expectLater(
        bloc.stream,
        emitsThrough(isA<ListEditorLoaded>()),
      );

      // Centang sub_1
      bloc.add(const ToggleListSubtaskDone(taskId: 'parent_1', subtaskId: 'sub_1'));
      var state = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      var task = state.listFile.tasks.firstWhere((t) => t.id == 'parent_1');
      expect(task.done, isFalse, reason: 'Baru 1 dari 2 subtask yang selesai');

      // Centang sub_2 -> sekarang semua subtask selesai
      bloc.add(const ToggleListSubtaskDone(taskId: 'parent_1', subtaskId: 'sub_2'));
      state = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      task = state.listFile.tasks.firstWhere((t) => t.id == 'parent_1');

      expect(task.done, isTrue, reason: 'Semua subtask selesai sehingga induk otomatis selesai');
      expect(task.subtasks[0].done, isTrue);
      expect(task.subtasks[1].done, isTrue);
    });

    test('4. Hilangkan centang satu sub task -> induk otomatis tidak tercentang', () async {
      final allDoneList = sampleList.copyWith(
        tasks: [
          const Task(
            id: 'parent_1',
            text: 'Tugas Utama 1',
            done: true,
            collapsed: false,
            subtasks: [
              Subtask(id: 'sub_1', text: 'Sub 1', done: true),
              Subtask(id: 'sub_2', text: 'Sub 2', done: true),
            ],
          ),
        ],
      );

      bloc.add(InitializeList(initialList: allDoneList));
      await expectLater(
        bloc.stream,
        emitsThrough(isA<ListEditorLoaded>()),
      );

      // Uncheck sub_2
      bloc.add(const ToggleListSubtaskDone(taskId: 'parent_1', subtaskId: 'sub_2'));
      final state = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      final task = state.listFile.tasks.firstWhere((t) => t.id == 'parent_1');

      expect(task.done, isFalse, reason: 'Salah satu subtask batal selesai sehingga induk batal selesai');
      expect(task.subtasks[0].done, isTrue);
      expect(task.subtasks[1].done, isFalse);
    });

    test('5. Task mandiri tanpa subtask: toggle done langsung mengubah status induk', () async {
      bloc.add(InitializeList(initialList: sampleList));
      await expectLater(
        bloc.stream,
        emitsThrough(isA<ListEditorLoaded>()),
      );

      bloc.add(const ToggleListTaskDone('parent_2'));
      var state = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      var task = state.listFile.tasks.firstWhere((t) => t.id == 'parent_2');
      expect(task.done, isTrue);

      bloc.add(const ToggleListTaskDone('parent_2'));
      state = await bloc.stream.firstWhere((s) => s is ListEditorLoaded) as ListEditorLoaded;
      task = state.listFile.tasks.firstWhere((t) => t.id == 'parent_2');
      expect(task.done, isFalse);
    });
  });
}
