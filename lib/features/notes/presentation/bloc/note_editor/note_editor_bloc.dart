import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'note_editor_event.dart';
import 'note_editor_state.dart';

class NoteEditorBloc extends Bloc<NoteEditorEvent, NoteEditorState> {
  final ExplorerRepository repository;
  final Uuid _uuid = const Uuid();
  String _folderRelativePath = '';

  NoteEditorBloc({required this.repository}) : super(NoteEditorInitial()) {
    on<InitializeNote>(_onInitializeNote);
    on<UpdateTitle>(_onUpdateTitle);
    on<UpdateContentDelta>(_onUpdateContentDelta);
    on<UpdateContent>(_onUpdateContent);
    on<SaveNoteEvent>(_onSaveNote);
    on<TogglePinInEditor>(_onTogglePin);
    on<DiscardEmptyNoteEvent>(_onDiscardEmptyNote);
    on<SetReminderInEditor>(_onSetReminder);
  }

  Future<void> _onInitializeNote(
    InitializeNote event,
    Emitter<NoteEditorState> emit,
  ) async {
    _folderRelativePath = event.folderRelativePath;
    emit(NoteEditorLoading());
    try {
      if (event.initialPage != null) {
        emit(NoteEditorLoaded(
          note: event.initialPage!,
          isNew: false,
          isDirty: false,
        ));
        return;
      }

      if (event.noteId != null && event.noteId != 'new' && event.noteId!.isNotEmpty) {
        final found = await _findPageById('', event.noteId!);
        if (found != null) {
          emit(NoteEditorLoaded(
            note: found,
            isNew: false,
            isDirty: false,
          ));
          return;
        }
      }

      final now = DateTime.now();
      final freshNote = PageFile(
        id: _uuid.v4(),
        relativePath: '',
        title: '',
        plainText: '',
        colorIndex: 0,
        favoritedAt: null,
        createdAt: now,
        updatedAt: now,
        content: const [],
      );
      emit(NoteEditorLoaded(
        note: freshNote,
        isNew: true,
        isDirty: false,
      ));
    } catch (e) {
      emit(NoteEditorError(e.toString()));
    }
  }

  Future<PageFile?> _findPageById(String folderRel, String id) async {
    final contents = await repository.getFolderContents(folderRel);
    for (final entry in contents) {
      if (entry is PageFile && entry.id == id) {
        return entry;
      } else if (entry is Folder) {
        final sub = await _findPageById(entry.relativePath, id);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  void _onUpdateTitle(
    UpdateTitle event,
    Emitter<NoteEditorState> emit,
  ) {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      emit(current.copyWith(
        note: current.note.copyWith(
          title: event.title,
          updatedAt: DateTime.now(),
        ),
        isDirty: true,
      ));
    }
  }

  void _onUpdateContentDelta(
    UpdateContentDelta event,
    Emitter<NoteEditorState> emit,
  ) {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      emit(current.copyWith(
        note: current.note.copyWith(
          content: event.content,
          plainText: event.plainText,
          updatedAt: DateTime.now(),
        ),
        isDirty: true,
      ));
    }
  }

  void _onUpdateContent(
    UpdateContent event,
    Emitter<NoteEditorState> emit,
  ) {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      emit(current.copyWith(
        note: current.note.copyWith(
          plainText: event.content,
          content: [
            {'insert': event.content},
            {'insert': '\n'}
          ],
          updatedAt: DateTime.now(),
        ),
        isDirty: true,
      ));
    }
  }

  Future<void> _onSaveNote(
    SaveNoteEvent event,
    Emitter<NoteEditorState> emit,
  ) async {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      if (current.note.title.trim().isEmpty && current.note.plainText.trim().isEmpty) {
        return;
      }

      emit(current.copyWith(isSaving: true));
      try {
        final toSave = current.note.copyWith(updatedAt: DateTime.now());
        final targetFolder = current.note.relativePath.isEmpty ? _folderRelativePath : null;
        final saved = await repository.savePage(
          toSave,
          targetFolderRelativePath: targetFolder,
        );
        emit(current.copyWith(
          note: saved,
          isSaving: false,
          isDirty: false,
          isNew: false,
        ));
      } catch (e) {
        emit(NoteEditorError(e.toString()));
      }
    }
  }

  Future<void> _onDiscardEmptyNote(
    DiscardEmptyNoteEvent event,
    Emitter<NoteEditorState> emit,
  ) async {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      if (current.note.relativePath.isNotEmpty) {
        try {
          await repository.deleteEntry(current.note);
        } catch (_) {}
      }
    }
  }

  Future<void> _onTogglePin(
    TogglePinInEditor event,
    Emitter<NoteEditorState> emit,
  ) async {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      final newFav = current.note.favoritedAt == null ? DateTime.now() : null;
      final updatedNote = current.note.copyWith(
        favoritedAt: newFav,
        clearFavoritedAt: newFav == null,
      );

      if (current.note.relativePath.isNotEmpty) {
        try {
          final saved = await repository.toggleFavorite(current.note);
          if (saved is PageFile) {
            emit(current.copyWith(note: saved, isDirty: false));
            return;
          }
        } catch (e) {
          emit(NoteEditorError(e.toString()));
          return;
        }
      }

      emit(current.copyWith(note: updatedNote, isDirty: true));
    }
  }

  void _onSetReminder(
    SetReminderInEditor event,
    Emitter<NoteEditorState> emit,
  ) {
    // PRD M1 removed reminderAt, keep as no-op for backward UI compat
  }
}
