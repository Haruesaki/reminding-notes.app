import '../../../explorer/domain/entities/entities.dart';

/// Layanan berbagi teks .txt.
/// Domain murni: tidak mengimpor dart:io, package:flutter, atau plugin.
abstract class TextShareService {
  /// Bersihkan direktori share yatim dari sesi sebelumnya saat startup.
  Future<void> cleanupOrphanShareDirs();

  /// Membagikan FileEntry sebagai file .txt melalui share sheet sistem.
  Future<void> shareFile(FileEntry file);
}
