import 'package:equatable/equatable.dart';
import '../../../../explorer/domain/entities/entities.dart';

abstract class ListEditorState extends Equatable {
  const ListEditorState();

  @override
  List<Object?> get props => [];
}

class ListEditorInitial extends ListEditorState {}

class ListEditorLoading extends ListEditorState {}

class ListEditorLoaded extends ListEditorState {
  final ListFile listFile;
  final bool isNew;
  final bool isDirty;

  const ListEditorLoaded({
    required this.listFile,
    this.isNew = false,
    this.isDirty = false,
  });

  ListEditorLoaded copyWith({
    ListFile? listFile,
    bool? isNew,
    bool? isDirty,
  }) {
    return ListEditorLoaded(
      listFile: listFile ?? this.listFile,
      isNew: isNew ?? this.isNew,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [listFile, isNew, isDirty];
}

class ListEditorError extends ListEditorState {
  final String message;
  const ListEditorError(this.message);

  @override
  List<Object?> get props => [message];
}
