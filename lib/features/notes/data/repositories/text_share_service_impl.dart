import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/app_logger.dart';

import 'package:reminding/features/explorer/domain/entities/entities.dart';
import 'package:reminding/features/notes/domain/repositories/text_share_service.dart';
import 'package:reminding/features/notes/domain/services/share_text_builder.dart';

/// Implementasi TextShareService dengan path_provider, dart:io, dan share_plus.
/// Data layer: boleh mengimpor dart:io dan plugin.
class TextShareServiceImpl implements TextShareService {
  static const _shareSubDir = 'reminding_share';

  @override
  Future<void> cleanupOrphanShareDirs() async {
    try {
      final dir = await _shareTempDir();
      if (!await dir.exists()) return;
      await dir.delete(recursive: true);
    } catch (e, st) {
          AppLogger.error(e, st);
        }
  }

  Future<Directory> _shareTempDir() async {
    return Directory(p.join((await getTemporaryDirectory()).path, _shareSubDir));
  }

  @override
  Future<void> shareFile(FileEntry file) async {
    final dir = await _shareTempDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = ShareTextBuilder.getShareFileName(file);
    final textFile = File(p.join(dir.path, fileName));
    final content = ShareTextBuilder.formatAsPlainText(file);
    await textFile.writeAsString(content);

    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(textFile.path)],
        subject: file.title,
      ),
    );
    // File temporary tetap dibersihkan baik share sukses maupun dibatalkan.
    if (result.status == ShareResultStatus.success) {
      // Berhasil dibagikan.
    }
    await _deleteShareFile(textFile);
  }

  Future<void> _deleteShareFile(File textFile) async {
    try {
      if (await textFile.exists()) {
        await textFile.delete();
      }
    } catch (e, st) {
          AppLogger.error(e, st);
        }
  }
}
