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
    on<CreateFolderEvent>(_onCreateFolder);
    on<ReorderEntriesEvent>(_onReorderEntries);
    on<MoveEntryEvent>(_onMoveEntry);
    on<CopyFileEvent>(_onCopyFile);
    on<RenameFolderEvent>(_onRenameFolder);
    on<DeleteFolderEvent>(_onDeleteFolder);
  }

  Future<({List<Folder> folders, List<FileEntry> files})> _fetchFilteredContent({
    String folderRelativePath = '',
    DateTime? selectedDate,
    String? query,
    HomeFilter filter = HomeFilter.semua,
  }) async {
    final contents = await repository.getFolderContents(folderRelativePath);
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
      folders = [];
      files = files.where((f) {
        if (f is ListFile) {
          return f.tasks.any((t) =>
              t.deadline != null &&
              t.deadline!.at.year == selectedDate.year &&
              t.deadline!.at.month == selectedDate.month &&
              t.deadline!.at.day == selectedDate.day);
        }
        return false;
      }).toList();
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
        folderRelativePath: event.folderRelativePath,
        selectedDate: event.date,
        query: event.query,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: event.folderRelativePath,
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
    String folderRel = '';

    if (currentState is NoteListLoaded) {
      folderRel = currentState.folderRelativePath;
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
        folderRelativePath: folderRel,
        selectedDate: newDate,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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
    String folderRel = '';

    if (currentState is NoteListLoaded) {
      folderRel = currentState.folderRelativePath;
      date = currentState.selectedDate;
      filter = currentState.currentFilter;
    }

    try {
      if (event.query.trim().isEmpty) {
        final result = await _fetchFilteredContent(
          folderRelativePath: folderRel,
          selectedDate: date,
          query: null,
          filter: filter,
        );
        emit(NoteListLoaded(
          folderRelativePath: folderRel,
          folders: result.folders,
          files: result.files,
          selectedDate: date,
          searchQuery: '',
          currentFilter: filter,
          searchResults: null,
        ));
      } else {
        final searchResults = await repository.searchGlobal(event.query);
        emit(NoteListLoaded(
          folderRelativePath: folderRel,
          folders: const [],
          files: searchResults.map((r) => r.file).toList(),
          selectedDate: date,
          searchQuery: event.query,
          currentFilter: filter,
          searchResults: searchResults,
        ));
      }
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
    String folderRel = '';

    if (currentState is NoteListLoaded) {
      folderRel = currentState.folderRelativePath;
      date = currentState.selectedDate;
      query = currentState.searchQuery;
    }

    try {
      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: event.filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      final contents = await repository.getFolderContents(folderRel);
      final entry = contents.firstWhere(
        (e) => e.id == event.id,
        orElse: () => throw Exception('Note not found'),
      );
      await repository.deleteEntry(entry);

      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      final contents = await repository.getFolderContents(folderRel);
      final entry = contents.firstWhere(
        (e) => e.id == event.id && e is FileEntry,
        orElse: () => throw Exception('Note not found'),
      );
      await repository.toggleFavorite(entry as FileEntry);

      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onCreateFolder(
    CreateFolderEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.createFolder(
        name: event.name,
        parentRelativePath: event.parentRelativePath,
      );

      final currentState = state;
      final folderRel = currentState is NoteListLoaded
          ? currentState.folderRelativePath
          : event.parentRelativePath;
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onReorderEntries(
    ReorderEntriesEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.saveOrder(
        folderRelativePath: event.folderRelativePath,
        newOrder: event.newOrder,
      );
      final currentState = state;
      final folderRel = event.folderRelativePath;
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onMoveEntry(
    MoveEntryEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.moveEntry(
        entry: event.entry,
        destinationFolderRelativePath: event.destinationFolderRelativePath,
      );
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onCopyFile(
    CopyFileEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.copyFile(
        file: event.file,
        destinationFolderRelativePath: event.destinationFolderRelativePath,
      );
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onRenameFolder(
    RenameFolderEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.renameFolder(
        folderRelativePath: event.folderRelativePath,
        newName: event.newName,
      );
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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

  Future<void> _onDeleteFolder(
    DeleteFolderEvent event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await repository.deleteEntry(event.folder);
      final currentState = state;
      final folderRel = currentState is NoteListLoaded ? currentState.folderRelativePath : '';
      DateTime? date;
      String query = '';
      HomeFilter filter = HomeFilter.semua;

      if (currentState is NoteListLoaded) {
        date = currentState.selectedDate;
        query = currentState.searchQuery;
        filter = currentState.currentFilter;
      }

      final result = await _fetchFilteredContent(
        folderRelativePath: folderRel,
        selectedDate: date,
        query: query.isNotEmpty ? query : null,
        filter: filter,
      );
      emit(NoteListLoaded(
        folderRelativePath: folderRel,
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
