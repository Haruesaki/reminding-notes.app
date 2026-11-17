import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:reminding/features/explorer/domain/entities/tone_ref.dart';
import 'package:reminding/features/notes/data/datasources/tones_local_data_source.dart';
import 'package:reminding/features/notes/domain/repositories/tones_repository.dart';

/// Implementasi TonesRepository yang mendegarkan ke TonesLocalDataSource.
/// Data layer: boleh mengimpor dart:io.
class TonesRepositoryImpl implements TonesRepository {
  final TonesLocalDataSource _dataSource;

  TonesRepositoryImpl(this._dataSource);

  @override
  Future<List<ToneRef>> getTones() => _dataSource.getTones();

  @override
  Future<ToneRef?> getToneById(String id) => _dataSource.getToneById(id);

  @override
  Future<ToneRef> addTone({
    required String filePath,
    required String name,
  }) async {
    final sourceFile = File(filePath);
    return _dataSource.addTone(sourceFile: sourceFile, name: name);
  }

  @override
  Future<void> deleteTone(String toneId) => _dataSource.deleteTone(toneId);

  @override
  Future<void> reRegisterAllTones() => _dataSource.reRegisterAllTones();

  @override
  Future<void> resetToneInTasks(String toneId) =>
      _dataSource.resetToneInTasks(toneId);

  @override
  Future<int> countAffectedTasks(String toneId) =>
      _dataSource.countAffectedTasks(toneId);

  /// Cek apakah file nada ada di disk (digunakan oleh presentasi untuk pratinjau).
  @override
  Future<bool> toneFileExists(String relativePath) async {
    final file = File(p.join(_dataSource.assetsDir.path, relativePath));
    return file.existsSync();
  }
}
