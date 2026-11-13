import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/name_sanitizer.dart';
import '../../../explorer/domain/entities/entities.dart';

class FileShareService {
  /// Direktori induk untuk file .txt sementara hasil share.
  static Future<Directory> _shareTempDir() async {
    return Directory(p.join((await getTemporaryDirectory()).path, 'reminding_share'));
  }

  /// Bersihkan direktori share yatim dari sesi sebelumnya saat startup (R3 T6).
  /// Tidak boleh melemahkan apapun (path_provider tidak tersedia di semua uji).
  static Future<void> cleanupOrphanShareDirs() async {
    try {
      final dir = await _shareTempDir();
      if (!await dir.exists()) return;
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Mengubah FileEntry menjadi representasi teks murni (.txt).
  /// Sesuai PRD 7.9:
  /// - PageFile: judul + dua newline + plainText
  /// - ListFile: judul + dua newline + list "[ ] teks" / "[x] teks", subtask diindentasi 4 spasi
  /// Dilarang mengirim JSON!
  static String formatAsPlainText(FileEntry file) {
    final title = file.title.trim().isEmpty ? 'Tanpa judul' : file.title.trim();
    final buffer = StringBuffer();
    buffer.writeln(title);
    buffer.writeln();

    if (file is PageFile) {
      buffer.write(file.plainText.trim());
    } else if (file is ListFile) {
      for (int i = 0; i < file.tasks.length; i++) {
        final task = file.tasks[i];
        final check = task.done ? '[x]' : '[ ]';
        buffer.writeln('$check ${task.text}');
        for (final sub in task.subtasks) {
          final subCheck = sub.done ? '[x]' : '[ ]';
          buffer.writeln('    $subCheck ${sub.text}');
        }
      }
    }

    return buffer.toString().trimRight();
  }

  /// Menghasilkan nama file .txt yang bersih dan unik berdasarkan judul.
  /// Sufix timestamp mencegah benturan bila dua catatan berjudul sama
  /// dibagikan berturut-turut (PRD 7.9, R3 T6).
  static String getShareFileName(FileEntry file) {
    final sanitized = NameSanitizer.sanitize(file.title);
    if (sanitized == 'unnamed' || sanitized.isEmpty) {
      return 'Catatan-${DateTime.now().millisecondsSinceEpoch}.txt';
    }
    return '$sanitized-${DateTime.now().millisecondsSinceEpoch}.txt';
  }

  /// Menulis file .txt sementara ke direktori share temp.
  static Future<File> createShareTextFile(
    FileEntry file, {
    Directory? directory,
  }) async {
    final dir = directory ?? await _shareTempDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = getShareFileName(file);
    final textFile = File(p.join(dir.path, fileName));
    final content = formatAsPlainText(file);
    await textFile.writeAsString(content);
    return textFile;
  }

  /// Membuka share sheet sistem untuk membagikan file .txt.
  /// File temporary dihapus setelah [ShareResult] diterima (R3 T6).
  static Future<void> shareFile(
    FileEntry file, {
    Directory? directory,
  }) async {
    final textFile = await createShareTextFile(file, directory: directory);
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(textFile.path)],
        subject: file.title,
      ),
    );
    // result.Status menunjukkan hasil share (tidak dibuang per R3 T6);
    // file temporary tetap dibersihkan baik share sukses maupun dibatalkan.
    if (result.status == ShareResultStatus.success) {
      // Berhasil dibagikan.
    }
    _deleteShareFile(textFile);
  }

  /// Hapus file .txt temporary setelah dibagikan.
  static Future<void> _deleteShareFile(File textFile) async {
    try {
      if (await textFile.exists()) {
        await textFile.delete();
      }
    } catch (_) {}
  }
}
