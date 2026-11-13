import '../../../explorer/domain/entities/entities.dart';
import '../../../../core/utils/name_sanitizer.dart';

/// Pembangun teks .txt murni dari [FileEntry].
/// Domain murni: tidak mengimpor dart:io, package:flutter, atau plugin.
/// Sesuai PRD 7.9:
/// - PageFile: judul + dua newline + plainText
/// - ListFile: judul + dua newline + list "[ ] teks" / "[x] teks", subtask diindentasi 4 spasi
/// Dilarang mengirim JSON!
class ShareTextBuilder {
  /// Mengubah FileEntry menjadi representasi teks murni (.txt).
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
  /// dibagikan berturut-turut (PRD 7.9).
  static String getShareFileName(FileEntry file) {
    final sanitized = NameSanitizer.sanitize(file.title);
    if (sanitized == 'unnamed' || sanitized.isEmpty) {
      return 'Catatan-${DateTime.now().millisecondsSinceEpoch}.txt';
    }
    return '$sanitized-${DateTime.now().millisecondsSinceEpoch}.txt';
  }
}
