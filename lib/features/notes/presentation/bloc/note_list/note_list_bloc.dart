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
    on<SelectCategoryFilter>(_onSelectCategoryFilter);
    on<DeleteNoteEvent>(_onDeleteNote);
    on<TogglePinEvent>(_onTogglePin);
  }

  Future<List<FileEntry>> _fetchFilteredFiles({
    DateTime? selectedDate,
    String? query,
    String? category,
  }) async {
    final contents = await repository.getFolderContents('');
    var files = contents.whereType<FileEntry>().toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
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

    if (selectedDate != null) {
      files = files.where((f) {
        return f.updatedAt.year == selectedDate.year &&
            f.updatedAt.month == selectedDate.month &&
            f.updatedAt.day == selectedDate.day;
      }).toList();
    }

    return files;
  }

  Future<void> _onLoadNotes(
    LoadNotes event,
    Emitter<NoteListState> emit,
  ) async {
    emit(NoteListLoading());
    try {
      final notes = await _fetchFilteredFiles(
        selectedDate: event.date,
        query: event.query,
        category: event.category,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: event.date,
        searchQuery: event.query ?? '',
        selectedCategory: event.category,
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
    String? category;

    if (currentState is NoteListLoaded) {
      if (currentState.selectedDate != null &&
          event.date != null &&
          currentState.selectedDate!.year == event.date!.year &&
          currentState.selectedDate!.month == event.date!.month &&
          currentState.selectedDate!.day == event.date!.day) {
        newDate = null;
      }
      query = currentState.searchQuery;
      category = currentState.selectedCategory;
    }

    try {
      final notes = await _fetchFilteredFiles(
        selectedDate: newDate,
        query: query.isNotEmpty ? query : null,
        category: category,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: newDate,
        searchQuery: query,
        selectedCategory: category,
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
    String? category;

    if (currentState is NoteListLoaded) {
      date = currentState.selectedDate;
      category = currentState.selectedCategory;
    }

    try {
      final notes = await _fetchFilteredFiles(
        selectedDate: date,
        query: event.query.isNotEmpty ? event.query : null,
        category: category,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: date,
        searchQuery: event.query,
        selectedCategory: category,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }

  Future<void> _onSelectCategoryFilter(
    SelectCategoryFilter event,
    Emitter<NoteListState> emit,
  ) async {
    final currentState = state;
    DateTime? date;
    String query = '';
    String? newCategory = event.category;

    if (currentState is NoteListLoaded) {
      date = currentState.selectedDate;
      query = currentState.searchQuery;
      if (currentState.selectedCategory == event.category) {
        newCategory = null;
      }
    }

    try {
      final notes = await _fetchFilteredFiles(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        category: newCategory,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: date,
        searchQuery: query,
        selectedCategory: newCategory,
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
      String? category;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        category = currentState.selectedCategory;
      }

      final notes = await _fetchFilteredFiles(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        category: category,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: date,
        searchQuery: query,
        selectedCategory: category,
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
      String? category;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        category = currentState.selectedCategory;
      }

      final notes = await _fetchFilteredFiles(
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        category: category,
      );
      emit(NoteListLoaded(
        notes: notes,
        selectedDate: date,
        searchQuery: query,
        selectedCategory: category,
      ));
    } catch (e) {
      emit(NoteListError(e.toString()));
    }
  }
}
