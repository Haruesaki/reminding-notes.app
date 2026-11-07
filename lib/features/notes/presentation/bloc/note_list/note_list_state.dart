import 'package:equatable/equatable.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

abstract class NoteListState extends Equatable {
  const NoteListState();

  @override
  List<Object?> get props => [];
}

class NoteListInitial extends NoteListState {}

class NoteListLoading extends NoteListState {}

class NoteListLoaded extends NoteListState {
  final List<FileEntry> notes;
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
    List<FileEntry>? notes,
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
