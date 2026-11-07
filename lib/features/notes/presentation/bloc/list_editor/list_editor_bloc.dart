import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../explorer/domain/entities/entities.dart';
import '../../../../explorer/domain/repositories/explorer_repository.dart';
import 'list_editor_event.dart';
import 'list_editor_state.dart';

class ListEditorBloc extends Bloc<ListEditorEvent, ListEditorState> {
  final ExplorerRepository repository;
  final Uuid _uuid = const Uuid();
  String _folderRelativePath = '';

  ListEditorBloc({required this.repository}) : super(ListEditorInitial()) {
    on<InitializeList>(_onInitializeList);
    on<UpdateListTitle>(_onUpdateTitle);
    on<ToggleListTaskDone>(_onToggleTaskDone);
    on<ToggleListSubtaskDone>(_onToggleSubtaskDone);
    on<AddListTask>(_onAddTask);
    on<AddListSubtask>(_onAddSubtask);
    on<UpdateListTaskText>(_onUpdateTaskText);
    on<UpdateListSubtaskText>(_onUpdateSubtaskText);
    on<DeleteListTask>(_onDeleteTask);
    on<DeleteListSubtask>(_onDeleteSubtask);
    on<RestoreListTask>(_onRestoreTask);
    on<ToggleListTaskCollapse>(_onToggleTaskCollapse);
    on<ToggleListPinInEditor>(_onTogglePin);
    on<SaveListEvent>(_onSaveList);
    on<DiscardEmptyListEvent>(_onDiscardEmptyList);
    on<UpdateTaskSettings>(_onUpdateTaskSettings);
  }

  Future<void> _onInitializeList(
    InitializeList event,
    Emitter<ListEditorState> emit,
  ) async {
    _folderRelativePath = event.folderRelativePath;
    emit(ListEditorLoading());
    try {
      if (event.initialList != null) {
        emit(ListEditorLoaded(
          listFile: event.initialList!,
          isNew: false,
          isDirty: false,
        ));
        return;
      }

      if (event.listId != null &&
          event.listId != 'new' &&
          event.listId!.isNotEmpty) {
        final found = await _findListById('', event.listId!);
        if (found != null) {
          emit(ListEditorLoaded(
            listFile: found,
            isNew: false,
            isDirty: false,
          ));
          return;
        }
      }

      final now = DateTime.now();
      final freshList = ListFile(
        id: _uuid.v4(),
        relativePath: '',
        title: '',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
        tasks: const [],
      );
      emit(ListEditorLoaded(
        listFile: freshList,
        isNew: true,
        isDirty: false,
      ));
    } catch (e) {
      emit(ListEditorError(e.toString()));
    }
  }

  Future<ListFile?> _findListById(String folderRel, String id) async {
    final contents = await repository.getFolderContents(folderRel);
    for (final entry in contents) {
      if (entry is ListFile && entry.id == id) {
        return entry;
      } else if (entry is Folder) {
        final found = await _findListById(entry.relativePath, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _onUpdateTitle(
    UpdateListTitle event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    emit(current.copyWith(
      listFile: current.listFile.copyWith(title: event.title),
      isDirty: true,
    ));
  }

  void _onToggleTaskDone(
    ToggleListTaskDone event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        final newDone = !task.done;
        final newSubtasks =
            task.subtasks.map((st) => st.copyWith(done: newDone)).toList();
        return task.copyWith(done: newDone, subtasks: newSubtasks);
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onToggleSubtaskDone(
    ToggleListSubtaskDone event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        final newSubtasks = task.subtasks.map((st) {
          if (st.id == event.subtaskId) {
            return st.copyWith(done: !st.done);
          }
          return st;
        }).toList();

        // Aturan centang:
        // Semua sub task tercentang -> induk tercentang;
        // Hilangkan centang satu sub task -> induk tidak tercentang.
        final allDone =
            newSubtasks.isNotEmpty && newSubtasks.every((st) => st.done);
        return task.copyWith(done: allDone, subtasks: newSubtasks);
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onAddTask(
    AddListTask event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final newTask = Task(
      id: _uuid.v4(),
      text: event.initialText,
      done: false,
      collapsed: false,
      subtasks: const [],
    );

    List<Task> newTasks;
    if (event.afterTaskId != null) {
      final index = current.listFile.tasks
          .indexWhere((t) => t.id == event.afterTaskId);
      if (index != -1) {
        newTasks = List<Task>.from(current.listFile.tasks)
          ..insert(index + 1, newTask);
      } else {
        newTasks = List<Task>.from(current.listFile.tasks)..add(newTask);
      }
    } else {
      newTasks = List<Task>.from(current.listFile.tasks)..add(newTask);
    }

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: newTasks),
      isDirty: true,
    ));
  }

  void _onAddSubtask(
    AddListSubtask event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final newSubtask = Subtask(
      id: _uuid.v4(),
      text: event.initialText,
      done: false,
    );

    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.parentTaskId) {
        final newSubtasks = List<Subtask>.from(task.subtasks)..add(newSubtask);
        final allDone = newSubtasks.every((st) => st.done);
        return task.copyWith(
          collapsed: false,
          done: allDone,
          subtasks: newSubtasks,
        );
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onUpdateTaskText(
    UpdateListTaskText event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        return task.copyWith(text: event.newText);
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onUpdateSubtaskText(
    UpdateListSubtaskText event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        final newSubtasks = task.subtasks.map((st) {
          if (st.id == event.subtaskId) {
            return st.copyWith(text: event.newText);
          }
          return st;
        }).toList();
        return task.copyWith(subtasks: newSubtasks);
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onDeleteTask(
    DeleteListTask event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks =
        current.listFile.tasks.where((t) => t.id != event.taskId).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onDeleteSubtask(
    DeleteListSubtask event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        final newSubtasks =
            task.subtasks.where((st) => st.id != event.subtaskId).toList();
        final allDone =
            newSubtasks.isNotEmpty && newSubtasks.every((st) => st.done);
        return task.copyWith(
          done: newSubtasks.isEmpty ? task.done : allDone,
          subtasks: newSubtasks,
        );
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onRestoreTask(
    RestoreListTask event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final newTasks = List<Task>.from(current.listFile.tasks);
    final insertIdx = event.index.clamp(0, newTasks.length);
    newTasks.insert(insertIdx, event.task);

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: newTasks),
      isDirty: true,
    ));
  }

  void _onUpdateTaskSettings(
    UpdateTaskSettings event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.updatedTask.id) {
        return event.updatedTask;
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
      isDirty: true,
    ));
  }

  void _onToggleTaskCollapse(
    ToggleListTaskCollapse event,
    Emitter<ListEditorState> emit,
  ) {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final updatedTasks = current.listFile.tasks.map((task) {
      if (task.id == event.taskId) {
        return task.copyWith(collapsed: !task.collapsed);
      }
      return task;
    }).toList();

    emit(current.copyWith(
      listFile: current.listFile.copyWith(tasks: updatedTasks),
    ));
  }

  Future<void> _onTogglePin(
    ToggleListPinInEditor event,
    Emitter<ListEditorState> emit,
  ) async {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final isFav = current.listFile.isFavorite;
    final updated = current.listFile.copyWith(
      favoritedAt: isFav ? null : DateTime.now().toUtc(),
      clearFavoritedAt: isFav,
    );
    emit(current.copyWith(listFile: updated, isDirty: true));
    add(const SaveListEvent());
  }

  Future<void> _onSaveList(
    SaveListEvent event,
    Emitter<ListEditorState> emit,
  ) async {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    final file = current.listFile;

    final isEmpty = file.title.trim().isEmpty &&
        file.tasks.every((t) =>
            t.text.trim().isEmpty &&
            t.subtasks.every((st) => st.text.trim().isEmpty));

    if (isEmpty) return;

    final finalTitle =
        file.title.trim().isEmpty ? 'Tanpa judul' : file.title.trim();
    final toSave = file.copyWith(
      title: finalTitle,
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      final targetFolder =
          current.listFile.relativePath.isEmpty ? _folderRelativePath : null;
      final saved = await repository.saveList(
        toSave,
        targetFolderRelativePath: targetFolder,
      );
      if (state is ListEditorLoaded) {
        final latest = state as ListEditorLoaded;
        emit(latest.copyWith(
          listFile: latest.listFile.copyWith(
            id: saved.id,
            relativePath: saved.relativePath,
            updatedAt: saved.updatedAt,
          ),
          isNew: false,
          isDirty: false,
        ));
      }
    } catch (e) {
      // Keep state
    }
  }

  Future<void> _onDiscardEmptyList(
    DiscardEmptyListEvent event,
    Emitter<ListEditorState> emit,
  ) async {
    if (state is! ListEditorLoaded) return;
    final current = state as ListEditorLoaded;
    if (current.isNew && current.listFile.relativePath.isNotEmpty) {
      try {
        await repository.deleteEntry(current.listFile);
      } catch (_) {}
    }
  }
}
