import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/note.dart';
import '../../../domain/repositories/note_repository.dart';
import 'note_editor_event.dart';
import 'note_editor_state.dart';

class NoteEditorBloc extends Bloc<NoteEditorEvent, NoteEditorState> {
  final NoteRepository repository;
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
        final existing = await repository.getNoteById(event.noteId!);
        if (existing != null) {
          emit(NoteEditorLoaded(
            note: existing,
            isNew: false,
            isDirty: false,
          ));
          return;
        }
      }

      final now = DateTime.now();
      final freshNote = Note(
        id: _uuid.v4(),
        title: '',
        content: '',
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
          content: event.content,
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
      // Do not save empty notes
      if (current.note.title.trim().isEmpty && current.note.content.trim().isEmpty) {
        return;
      }

      emit(current.copyWith(isSaving: true));
      try {
        final toSave = current.note.copyWith(updatedAt: DateTime.now());
        await repository.saveNote(toSave);
        emit(current.copyWith(
          note: toSave,
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
      final updated = current.note.copyWith(
        isPinned: !current.note.isPinned,
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(updated);
      emit(current.copyWith(note: updated, isDirty: false));
    }
  }

  void _onSetReminder(
    SetReminderInEditor event,
    Emitter<NoteEditorState> emit,
  ) {
    if (state is NoteEditorLoaded) {
      final current = state as NoteEditorLoaded;
      emit(current.copyWith(
        note: current.note.copyWith(
          reminderAt: event.reminderAt,
          updatedAt: DateTime.now(),
        ),
        isDirty: true,
      ));
    }
  }
}
