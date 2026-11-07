import 'package:equatable/equatable.dart';

abstract class NoteEditorEvent extends Equatable {
  const NoteEditorEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNote extends NoteEditorEvent {
  final String? noteId;

  const InitializeNote({this.noteId});

  @override
  List<Object?> get props => [noteId];
}

class UpdateTitle extends NoteEditorEvent {
  final String title;

  const UpdateTitle(this.title);

  @override
  List<Object?> get props => [title];
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

class SetReminderInEditor extends NoteEditorEvent {
  final DateTime? reminderAt;

  const SetReminderInEditor(this.reminderAt);

  @override
  List<Object?> get props => [reminderAt];
}
