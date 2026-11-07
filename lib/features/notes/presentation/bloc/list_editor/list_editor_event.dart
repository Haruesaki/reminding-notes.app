import 'package:equatable/equatable.dart';
import '../../../../explorer/domain/entities/entities.dart';

abstract class ListEditorEvent extends Equatable {
  const ListEditorEvent();

  @override
  List<Object?> get props => [];
}

class InitializeList extends ListEditorEvent {
  final String? listId;
  final String folderRelativePath;
  final ListFile? initialList;

  const InitializeList({
    this.listId,
    this.folderRelativePath = '',
    this.initialList,
  });

  @override
  List<Object?> get props => [listId, folderRelativePath, initialList];
}

class UpdateListTitle extends ListEditorEvent {
  final String title;
  const UpdateListTitle(this.title);

  @override
  List<Object?> get props => [title];
}

class ToggleListTaskDone extends ListEditorEvent {
  final String taskId;
  const ToggleListTaskDone(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class ToggleListSubtaskDone extends ListEditorEvent {
  final String taskId;
  final String subtaskId;
  const ToggleListSubtaskDone({required this.taskId, required this.subtaskId});

  @override
  List<Object?> get props => [taskId, subtaskId];
}

class AddListTask extends ListEditorEvent {
  final String? afterTaskId;
  final String initialText;
  const AddListTask({this.afterTaskId, this.initialText = ''});

  @override
  List<Object?> get props => [afterTaskId, initialText];
}

class AddListSubtask extends ListEditorEvent {
  final String parentTaskId;
  final String initialText;
  const AddListSubtask({required this.parentTaskId, this.initialText = ''});

  @override
  List<Object?> get props => [parentTaskId, initialText];
}

class UpdateListTaskText extends ListEditorEvent {
  final String taskId;
  final String newText;
  const UpdateListTaskText({required this.taskId, required this.newText});

  @override
  List<Object?> get props => [taskId, newText];
}

class UpdateListSubtaskText extends ListEditorEvent {
  final String taskId;
  final String subtaskId;
  final String newText;
  const UpdateListSubtaskText({
    required this.taskId,
    required this.subtaskId,
    required this.newText,
  });

  @override
  List<Object?> get props => [taskId, subtaskId, newText];
}

class DeleteListTask extends ListEditorEvent {
  final String taskId;
  const DeleteListTask(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class DeleteListSubtask extends ListEditorEvent {
  final String taskId;
  final String subtaskId;
  const DeleteListSubtask({required this.taskId, required this.subtaskId});

  @override
  List<Object?> get props => [taskId, subtaskId];
}

class RestoreListTask extends ListEditorEvent {
  final int index;
  final Task task;
  const RestoreListTask({required this.index, required this.task});

  @override
  List<Object?> get props => [index, task];
}

class ToggleListTaskCollapse extends ListEditorEvent {
  final String taskId;
  const ToggleListTaskCollapse(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class ToggleListPinInEditor extends ListEditorEvent {
  const ToggleListPinInEditor();
}

class SaveListEvent extends ListEditorEvent {
  const SaveListEvent();
}

class DiscardEmptyListEvent extends ListEditorEvent {
  const DiscardEmptyListEvent();
}
