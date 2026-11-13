import '../../../explorer/domain/entities/tone_ref.dart';

/// Repository abstrak untuk operasi nada kustom.
/// Domain murni: tidak mengimpor dart:io, package:flutter, atau plugin.
abstract class TonesRepository {
  /// Daftar semua nada terdaftar.
  Future<List<ToneRef>> getTones();

  /// Ambil nada theo ID.
  Future<ToneRef?> getToneById(String id);

  /// Tambah nada dari file path.
  Future<ToneRef> addTone({
    required String filePath,
    required String name,
  });

  /// Hapus nada theo ID.
  Future<void> deleteTone(String toneId);

  /// Daftarkan ulang semua nada ke MediaStore setelah impor backup.
  Future<void> reRegisterAllTones();

  /// Reset task yang memakai nada ini ke Bawaan Sistem.
  Future<void> resetToneInTasks(String toneId);

  /// Hitung jumlah task yang memakai nada ini.
  Future<int> countAffectedTasks(String toneId);

  /// Cek apakah file nada ada di disk (digunakan oleh presentasi untuk pratinjau).
  Future<bool> toneFileExists(String relativePath);
}
