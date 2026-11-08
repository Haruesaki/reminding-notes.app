import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/name_sanitizer.dart';
import '../../../explorer/domain/entities/entities.dart';

class FileShareService {
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

  /// Menghasilkan nama file .txt yang bersih berdasarkan judul
  static String getShareFileName(FileEntry file) {
    final sanitized = NameSanitizer.sanitize(file.title);
    if (sanitized == 'unnamed' || sanitized.isEmpty) {
      return 'Catatan.txt';
    }
    return '$sanitized.txt';
  }

  /// Menulis file .txt sementara
  static Future<File> createShareTextFile(
    FileEntry file, {
    Directory? directory,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final fileName = getShareFileName(file);
    final textFile = File(p.join(dir.path, fileName));
    final content = formatAsPlainText(file);
    await textFile.writeAsString(content);
    return textFile;
  }

  /// Membuka share sheet sistem untuk membagikan file .txt
  static Future<void> shareFile(
    FileEntry file, {
    Directory? directory,
  }) async {
    final textFile = await createShareTextFile(file, directory: directory);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(textFile.path)],
        subject: file.title,
      ),
    );
  }
}
