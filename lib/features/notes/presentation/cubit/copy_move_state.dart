import 'package:equatable/equatable.dart';
import '../../../explorer/domain/entities/entities.dart';

enum CopyMoveOperation { copy, move }

abstract class CopyMoveState extends Equatable {
  const CopyMoveState();

  @override
  List<Object?> get props => [];
}

class CopyMoveInactive extends CopyMoveState {
  const CopyMoveInactive();
}

class CopyMoveActive extends CopyMoveState {
  final NodeEntry entry;
  final CopyMoveOperation operation;
  final String sourceFolderRelativePath;

  const CopyMoveActive({
    required this.entry,
    required this.operation,
    required this.sourceFolderRelativePath,
  });

  String get entryTitleOrName {
    if (entry is FileEntry) {
      return (entry as FileEntry).title;
    } else if (entry is Folder) {
      return (entry as Folder).name;
    }
    return '';
  }

  @override
  List<Object?> get props => [entry, operation, sourceFolderRelativePath];
}
