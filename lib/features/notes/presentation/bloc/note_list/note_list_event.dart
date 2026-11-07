import 'package:equatable/equatable.dart';

abstract class NoteListEvent extends Equatable {
  const NoteListEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotes extends NoteListEvent {
  final DateTime? date;
  final String? query;
  final String? category;

  const LoadNotes({this.date, this.query, this.category});

  @override
  List<Object?> get props => [date, query, category];
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

class SelectCategoryFilter extends NoteListEvent {
  final String? category;

  const SelectCategoryFilter(this.category);

  @override
  List<Object?> get props => [category];
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
