import '../../../../core/usecase/usecase.dart';
import '../../../explorer/domain/entities/tone_ref.dart';
import '../repositories/tones_repository.dart';

/// Menambahkan nada kustom dari path file yang dipilih pengguna.
class AddToneUseCase implements UseCase<ToneRef, AddToneParams> {
  final TonesRepository repository;

  AddToneUseCase(this.repository);

  @override
  Future<ToneRef> call(AddToneParams params) {
    return repository.addTone(
      filePath: params.filePath,
      name: params.name,
    );
  }
}

/// Menghapus nada kustom.
class DeleteToneUseCase implements UseCase<void, String> {
  final TonesRepository repository;

  DeleteToneUseCase(this.repository);

  @override
  Future<void> call(String toneId) {
    return repository.deleteTone(toneId);
  }
}

class AddToneParams {
  final String filePath;
  final String name;

  const AddToneParams({
    required this.filePath,
    required this.name,
  });
}
