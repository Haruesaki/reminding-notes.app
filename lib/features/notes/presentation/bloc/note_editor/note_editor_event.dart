import 'package:equatable/equatable.dart';
import '../../../../explorer/domain/entities/entities.dart';

abstract class NoteEditorEvent extends Equatable {
  const NoteEditorEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNote extends NoteEditorEvent {
  final String? noteId;
  final String folderRelativePath;
  final PageFile? initialPage;

  const InitializeNote({
    this.noteId,
    this.folderRelativePath = '',
    this.initialPage,
  });

  @override
  List<Object?> get props => [noteId, folderRelativePath, initialPage];
}

class UpdateTitle extends NoteEditorEvent {
  final String title;

  const UpdateTitle(this.title);

  @override
  List<Object?> get props => [title];
}

class UpdateContentDelta extends NoteEditorEvent {
  final List<dynamic> content;
  final String plainText;

  const UpdateContentDelta({
    required this.content,
    required this.plainText,
  });

  @override
  List<Object?> get props => [content, plainText];
}

class UpdateContent extends NoteEditorEvent {
  final String content;

  const UpdateContent(this.content);

  @override
  List<Object?> get props => [content];
}

class SaveNoteEvent extends NoteEditorEvent {
  const SaveNoteEvent();
}

class TogglePinInEditor extends NoteEditorEvent {
  const TogglePinInEditor();
}

class DiscardEmptyNoteEvent extends NoteEditorEvent {
  const DiscardEmptyNoteEvent();
}

class SetReminderInEditor extends NoteEditorEvent {
  final DateTime? reminderAt;

  const SetReminderInEditor(this.reminderAt);

  @override
  List<Object?> get props => [reminderAt];
}
