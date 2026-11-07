import 'package:equatable/equatable.dart';
import '../../../domain/entities/note.dart';

abstract class NoteListState extends Equatable {
  const NoteListState();

  @override
  List<Object?> get props => [];
}

class NoteListInitial extends NoteListState {}

class NoteListLoading extends NoteListState {}

class NoteListLoaded extends NoteListState {
  final List<Note> notes;
  final DateTime? selectedDate;
  final String searchQuery;
  final String? selectedCategory;

  const NoteListLoaded({
    required this.notes,
    this.selectedDate,
    this.searchQuery = '',
    this.selectedCategory,
  });

  NoteListLoaded copyWith({
    List<Note>? notes,
    DateTime? Function()? selectedDate,
    String? searchQuery,
    String? Function()? selectedCategory,
  }) {
    return NoteListLoaded(
      notes: notes ?? this.notes,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory:
          selectedCategory != null ? selectedCategory() : this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [notes, selectedDate, searchQuery, selectedCategory];
}

class NoteListError extends NoteListState {
  final String message;

  const NoteListError(this.message);

  @override
  List<Object?> get props => [message];
}
