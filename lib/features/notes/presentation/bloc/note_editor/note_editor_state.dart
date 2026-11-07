import 'package:equatable/equatable.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

abstract class NoteEditorState extends Equatable {
  const NoteEditorState();

  @override
  List<Object?> get props => [];
}

class NoteEditorInitial extends NoteEditorState {}

class NoteEditorLoading extends NoteEditorState {}

class NoteEditorLoaded extends NoteEditorState {
  final PageFile note;
  final bool isNew;
  final bool isSaving;
  final bool isDirty;

  const NoteEditorLoaded({
    required this.note,
    required this.isNew,
    this.isSaving = false,
    this.isDirty = false,
  });

  NoteEditorLoaded copyWith({
    PageFile? note,
    bool? isNew,
    bool? isSaving,
    bool? isDirty,
  }) {
    return NoteEditorLoaded(
      note: note ?? this.note,
      isNew: isNew ?? this.isNew,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [note, isNew, isSaving, isDirty];
}

class NoteEditorError extends NoteEditorState {
  final String message;

  const NoteEditorError(this.message);

  @override
  List<Object?> get props => [message];
}
