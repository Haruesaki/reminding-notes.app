import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../explorer/domain/entities/entities.dart';
import 'copy_move_state.dart';

class CopyMoveCubit extends Cubit<CopyMoveState> {
  CopyMoveCubit() : super(const CopyMoveInactive());

  void startOperation({
    required NodeEntry entry,
    required CopyMoveOperation operation,
    required String sourceFolderRelativePath,
  }) {
    emit(CopyMoveActive(
      entry: entry,
      operation: operation,
      sourceFolderRelativePath: sourceFolderRelativePath,
    ));
  }

  void cancel() {
    emit(const CopyMoveInactive());
  }
}
