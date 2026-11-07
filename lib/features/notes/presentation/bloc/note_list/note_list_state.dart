import 'package:equatable/equatable.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

enum HomeFilter {
  semua('Semua'),
  favorit('Favorit'),
  folder('Folder'),
  list('List'),
  page('Page');

  final String label;
  const HomeFilter(this.label);
}

abstract class NoteListState extends Equatable {
  const NoteListState();

  @override
  List<Object?> get props => [];
}

class NoteListInitial extends NoteListState {}

class NoteListLoading extends NoteListState {}

class NoteListLoaded extends NoteListState {
  final String folderRelativePath;
  final List<Folder> folders;
  final List<FileEntry> files;
  final DateTime? selectedDate;
  final String searchQuery;
  final HomeFilter currentFilter;

  const NoteListLoaded({
    this.folderRelativePath = '',
    this.folders = const [],
    this.files = const [],
    this.selectedDate,
    this.searchQuery = '',
    this.currentFilter = HomeFilter.semua,
  });

  /// Backward compatibility getter for tests
  List<FileEntry> get notes => files;

  NoteListLoaded copyWith({
    String? folderRelativePath,
    List<Folder>? folders,
    List<FileEntry>? files,
    DateTime? Function()? selectedDate,
    String? searchQuery,
    HomeFilter? currentFilter,
  }) {
    return NoteListLoaded(
      folderRelativePath: folderRelativePath ?? this.folderRelativePath,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }

  @override
  List<Object?> get props =>
      [folderRelativePath, folders, files, selectedDate, searchQuery, currentFilter];
}

class NoteListError extends NoteListState {
  final String message;

  const NoteListError(this.message);

  @override
  List<Object?> get props => [message];
}
