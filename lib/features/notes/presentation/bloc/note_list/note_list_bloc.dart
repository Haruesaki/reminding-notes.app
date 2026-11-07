import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/note_repository.dart';
import 'note_list_event.dart';
import 'note_list_state.dart';

class NoteListBloc extends Bloc<NoteListEvent, NoteListState> {
  final NoteRepository repository;

  NoteListBloc({required this.repository}) : super(NoteListInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<SelectDateFilter>(_onSelectDateFilter);
    on<SearchNotes>(_onSearchNotes);
    on<SelectCategoryFilter>(_onSelectCategoryFilter);
    on<DeleteNoteEvent>(_onDeleteNote);
    on<TogglePinEvent>(_onTogglePin);
  }

  Future<void> _onLoadNotes(
    LoadNotes event,
    Emitter<NoteListState> emit,
  ) async {
    emit(NoteListLoading());
    try {
      final notes = await repository.getNotes(
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
        // Toggle off date selection if same date tapped
        newDate = null;
      }
      query = currentState.searchQuery;
      category = currentState.selectedCategory;
    }

    try {
      final notes = await repository.getNotes(
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
      final notes = await repository.getNotes(
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
        newCategory = null; // Toggle off
      }
    }

    try {
      final notes = await repository.getNotes(
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
      await repository.deleteNote(event.id);
      final currentState = state;
      DateTime? date;
      String query = '';
      String? category;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        category = currentState.selectedCategory;
      }

      final notes = await repository.getNotes(
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
      await repository.togglePin(event.id, event.isPinned);
      final currentState = state;
      DateTime? date;
      String query = '';
      String? category;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        category = currentState.selectedCategory;
      }

      final notes = await repository.getNotes(
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
