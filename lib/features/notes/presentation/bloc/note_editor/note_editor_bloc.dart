import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/explorer/domain/repositories/explorer_repository.dart';
import 'note_editor_event.dart';
import 'note_editor_state.dart';

class NoteEditorBloc extends Bloc<NoteEditorEvent, NoteEditorState> {
  final ExplorerRepository repository;
  final Uuid _uuid = const Uuid();

  NoteEditorBloc({required this.repository}) : super(NoteEditorInitial()) {
    on<InitializeNote>(_onInitializeNote);
    on<UpdateTitle>(_onUpdateTitle);
    on<UpdateContent>(_onUpdateContent);
    on<SaveNoteEvent>(_onSaveNote);
    on<TogglePinInEditor>(_onTogglePin);
    on<SetReminderInEditor>(_onSetReminder);
  }

  Future<void> _onInitializeNote(
    InitializeNote event,
    Emitter<NoteEditorState> emit,
  ) async {
    emit(NoteEditorLoading());
    try {
      if (event.noteId != null) {
        final contents = await repository.getFolderContents('');
        for (final entry in contents) {
          if (entry.id == event.noteId && entry is PageFile) {
            emit(NoteEditorLoaded(
              note: entry,
              isNew: false,
              isDirty: false,
            ));
            return;
          }
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
        final saved = await repository.savePage(toSave);
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

  Future<void> _onTogglePin(
    TogglePinInEditor event,
    Emitter<NoteEditorState> emit,
  ) async {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      try {
        final updated = await repository.toggleFavorite(current.note);
        if (updated is PageFile) {
          emit(current.copyWith(note: updated, isDirty: false));
        }
      } catch (e) {
        emit(NoteEditorError(e.toString()));
      }
    }
  }

  void _onSetReminder(
    SetReminderInEditor event,
    Emitter<NoteEditorState> emit,
  ) {
    // PRD M1 removed reminderAt, keep as no-op for backward UI compat
  }
}
