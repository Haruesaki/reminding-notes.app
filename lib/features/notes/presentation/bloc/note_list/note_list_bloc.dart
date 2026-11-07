import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'note_list_event.dart';
import 'note_list_state.dart';

class NoteListBloc extends Bloc<NoteListEvent, NoteListState> {
  final ExplorerRepository repository;

  NoteListBloc({required this.repository}) : super(NoteListInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<SelectDateFilter>(_onSelectDateFilter);
    on<SearchNotes>(_onSearchNotes);
    on<SelectFilterEvent>(_onSelectFilter);
    on<DeleteNoteEvent>(_onDeleteNote);
    on<TogglePinEvent>(_onTogglePin);
  }

  bool _matchesDate(FileEntry file, DateTime date) {
    if (file is ListFile) {
      if (file.tasks.any((t) =>
          t.deadline != null &&
          t.deadline!.at.year == date.year &&
          t.deadline!.at.month == date.month &&
          t.deadline!.at.day == date.day)) {
        return true;
      }
    }
    return file.updatedAt.year == date.year &&
        file.updatedAt.month == date.month &&
        file.updatedAt.day == date.day;
  }

  Future<({List<Folder> folders, List<FileEntry> files})> _fetchFilteredContent({
    DateTime? selectedDate,
    String? query,
    HomeFilter filter = HomeFilter.semua,
  }) async {
    final contents = await repository.getFolderContents('');
    var folders = contents.whereType<Folder>().toList();
    var files = contents.whereType<FileEntry>().toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      folders = folders.where((f) => f.name.toLowerCase().contains(q)).toList();
      files = files.where((f) {
        final titleMatch = f.title.toLowerCase().contains(q);
        final contentMatch = f is PageFile
            ? f.plainText.toLowerCase().contains(q)
            : (f is ListFile
                ? f.tasks.any((t) => t.text.toLowerCase().contains(q))
                : false);
        return titleMatch || contentMatch;
      }).toList();
    }

    switch (filter) {
      case HomeFilter.semua:
        break;
      case HomeFilter.favorit:
        folders = [];
        files = files.where((f) => f.isFavorite).toList();
        break;
      case HomeFilter.folder:
        files = [];
        break;
      case HomeFilter.list:
        folders = [];
        files = files.whereType<ListFile>().toList();
        break;
      case HomeFilter.page:
        folders = [];
        files = files.whereType<PageFile>().toList();
        break;
    }

    if (selectedDate != null) {
      final hasAnyDeadline = files.any(
          (f) => f is ListFile && f.tasks.any((t) => t.deadline != null));
      if (hasAnyDeadline) {
        files = files.where((f) => _matchesDate(f, selectedDate)).toList();
      }
    }

    return (folders: folders, files: files);
  }

  Future<void> _onLoadNotes(
    LoadNotes event,
    Emitter<NoteListState> emit,
  ) async {
    emit(NoteListLoading());
    try {
      final filter = event.filter ?? HomeFilter.semua;
      final result = await _fetchFilteredContent(
        selectedDate: event.date,
        query: event.query,
        filter: filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: event.date,
        searchQuery: event.query ?? '',
        currentFilter: filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onSelectDateFilter(
    SelectDateFilter event,
    Emitter<NoteListState> emit,
  ) async {
    final currentState = state;
    DateTime? newDate = event.date;
    String query = '';
    HomeFilter filter = HomeFilter.semua;

    if (currentState is NoteListLoaded) {
      if (currentState.selectedDate != null &&
          event.date != null &&
          currentState.selectedDate!.year == event.date!.year &&
          currentState.selectedDate!.month == event.date!.month &&
          currentState.selectedDate!.day == event.date!.day) {
        newDate = null;
      }
      query = currentState.searchQuery;
      filter = currentState.currentFilter;
    }

    try {
      final result = await _fetchFilteredContent(
        selectedDate: newDate,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: newDate,
        searchQuery: query,
        currentFilter: filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onSearchNotes(
    SearchNotes event,
    Emitter<NoteListState> emit,
  ) async {
    final currentState = state;
    DateTime? date;
    HomeFilter filter = HomeFilter.semua;

    if (currentState is NoteListLoaded) {
      date = currentState.selectedDate;
      filter = currentState.currentFilter;
    }

    try {
      final result = await _fetchFilteredContent(
        selectedDate: date,
        query: event.query.isNotEmpty ? event.query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: date,
        searchQuery: event.query,
        currentFilter: filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onSelectFilter(
    SelectFilterEvent event,
    Emitter<NoteListState> emit,
  ) async {
    final currentState = state;
    DateTime? date;
    String query = '';

    if (currentState is NoteListLoaded) {
      date = currentState.selectedDate;
      query = currentState.searchQuery;
    }

    try {
      final result = await _fetchFilteredContent(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: event.filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: date,
        searchQuery: query,
        currentFilter: event.filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onDeleteNote(
    DeleteNoteEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      final contents = await repository.getFolderContents('');
      final entry = contents.firstWhere(
        (e) => e.id == event.id,
        orElse: () => throw Exception('Note not found'),
      );
      await repository.deleteEntry(entry);

      final currentState = state;
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: date,
        searchQuery: query,
        currentFilter: filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onTogglePin(
    TogglePinEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      final contents = await repository.getFolderContents('');
      final entry = contents.firstWhere(
        (e) => e.id == event.id && e is FileEntry,
        orElse: () => throw Exception('Note not found'),
      );
      await repository.toggleFavorite(entry as FileEntry);

      final currentState = state;
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folders: result.folders,
        files: result.files,
        selectedDate: date,
        searchQuery: query,
        currentFilter: filter,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }
}
