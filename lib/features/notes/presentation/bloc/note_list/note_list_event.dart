import 'package:equatable/equatable.dart';
import 'note_list_state.dart';

abstract class NoteListEvent extends Equatable {
  const NoteListEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotes extends NoteListEvent {
  final DateTime? date;
  final String? query;
  final HomeFilter? filter;
  final String folderRelativePath;

  const LoadNotes({
    this.date,
    this.query,
    this.filter,
    this.folderRelativePath = '',
  });

  @override
  List<Object?> get props => [date, query, filter, folderRelativePath];
}

class SelectDateFilter extends NoteListEvent {
  final DateTime? date;

  const SelectDateFilter(this.date);

  @override
  List<Object?> get props => [date];
}

class SearchNotes extends NoteListEvent {
  final String query;

  const SearchNotes(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectFilterEvent extends NoteListEvent {
  final HomeFilter filter;

  const SelectFilterEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

class DeleteNoteEvent extends NoteListEvent {
  final String id;

  const DeleteNoteEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class TogglePinEvent extends NoteListEvent {
  final String id;
  final bool isPinned;

  const TogglePinEvent(this.id, this.isPinned);

  @override
  List<Object?> get props => [id, isPinned];
}

class CreateFolderEvent extends NoteListEvent {
  final String name;
  final String parentRelativePath;

  const CreateFolderEvent({
    required this.name,
    this.parentRelativePath = '',
  });

  @override
  List<Object?> get props => [name, parentRelativePath];
}
