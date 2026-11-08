import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Helper penulisan file secara atomik dan aman dari balapan I/O (PRD 6.1, 6.7).
///
/// Fitur:
/// - Serialisasi per target path (rantai Future) agar auto-save beruntun tidak saling menimpa.
/// - Penulisan ke file sementara unik (`<target>.<uuid>.tmp`) dengan flush.
/// - Rename langsung ke target TANPA menghapus file target terlebih dahulu.
/// - Fallback copy jika rename gagal, juga tanpa menghapus target lebih dulu.
/// - Pemulihan berkas .tmp yatim pada saat init.
class AtomicFileWriter {
  static final Map<String, Future<void>> _locks = {};
  static const Uuid _uuid = Uuid();

  /// Titik suntik kegagalan untuk testing: melempar exception tepat sebelum rename.
  @visibleForTesting
  static bool failBeforeRename = false;

  /// Callback testing opsional yang dipanggil tepat sebelum rename dilakukan.
  @visibleForTesting
  static Future<void> Function(File tmpFile, File targetFile)? onBeforeRename;

  /// Reset state lock & hooks untuk isolasi test.
  @visibleForTesting
  static void resetForTesting() {
    failBeforeRename = false;
    onBeforeRename = null;
    _locks.clear();
  }

  /// Menjalankan [action] secara terserialisasi per target path.
  static final Set<Future<void>> _activeWrites = {};

  /// Menunggu semua penulisan yang sedang berjalan selesai.
  static Future<void> waitForPendingWrites() async {
    while (_activeWrites.isNotEmpty) {
      final futures = _activeWrites.toList();
      await Future.wait(futures.map((f) => f.catchError((_) {})));
    }
  }

  static Future<T> _synchronized<T>(String path, Future<T> Function() action) {
    final key = p.canonicalize(path).toLowerCase();
    final prev = _locks[key] ?? Future.value();
    final completer = Completer<T>();

    final next = prev.catchError((_) {}).then((_) async {
      try {
        final res = await action();
        completer.complete(res);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    _locks[key] = next;
    _activeWrites.add(next);

    next.whenComplete(() {
      _activeWrites.remove(next);
      if (identical(_locks[key], next)) {
        _locks.remove(key);
      }
    });

    return completer.future;
  }

  /// Menghasilkan representasi string JSON dengan indent 2 spasi dan diakhiri newline.
  static String encodeJson(Map<String, dynamic> data) {
    return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
  }

  /// Menulis peta data JSON secara atomik ke [targetFile].
  static Future<void> writeJson(
    File targetFile,
    Map<String, dynamic> jsonMap, {
    Uuid? uuid,
  }) async {
    final content = encodeJson(jsonMap);
    await writeString(targetFile, content, uuid: uuid);
  }

  /// Menulis string [content] secara atomik ke [targetFile].
  static Future<void> writeString(
    File targetFile,
    String content, {
    Uuid? uuid,
  }) async {
    await _synchronized(targetFile.path, () async {
      final parentDir = targetFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      final id = (uuid ?? _uuid).v4();
      final tmpFile = File('${targetFile.path}.$id.tmp');

      try {
        await tmpFile.writeAsString(content, encoding: utf8, flush: true);

        if (failBeforeRename) {
          throw FileSystemException('Injected failure before rename', tmpFile.path);
        }
        if (onBeforeRename != null) {
          await onBeforeRename!(tmpFile, targetFile);
        }

        try {
          // DILARANG menghapus target sebelum rename.
          await tmpFile.rename(targetFile.path);
        } catch (e) {
          // Fallback (copy) hanya bila rename gagal, juga tanpa menghapus target lebih dulu.
          await tmpFile.copy(targetFile.path);
          if (await tmpFile.exists()) {
            try {
              await tmpFile.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        if (await tmpFile.exists()) {
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
        rethrow;
      }
    });
  }

  /// Mengembalikan target path dari sebuah file .tmp (baik format baru `<name>.<uuid>.tmp`
  /// maupun format legacy `<name>.tmp`).
  static String? resolveTargetFromTmpPath(String tmpPath) {
    if (!tmpPath.endsWith('.tmp')) return null;
    final dir = p.dirname(tmpPath);
    final filename = p.basename(tmpPath);

    // Format target berekstensi json: <target_name.json>.<token>.tmp
    final jsonMatch = RegExp(r'^(.*\.json)\.[^.]+\.tmp$', caseSensitive: false).firstMatch(filename);
    if (jsonMatch != null) {
      return p.join(dir, jsonMatch.group(1));
    }

    // Format baru: <target_name>.<uuid_atau_token>.tmp
    final uuidMatch = RegExp(r'^(.*)\.[0-9a-zA-Z-]{6,}\.tmp$').firstMatch(filename);
    if (uuidMatch != null) {
      return p.join(dir, uuidMatch.group(1));
    }

    // Format legacy: <target_name>.tmp
    final legacyMatch = RegExp(r'^(.*)\.tmp$').firstMatch(filename);
    if (legacyMatch != null) {
      return p.join(dir, legacyMatch.group(1));
    }

    return null;
  }

  /// Memulihkan file *.tmp yatim di dalam [directory] (secara rekursif):
  /// - Bila target hilang dan tmp berisi JSON valid -> promosikan menjadi target.
  /// - Bila target ada -> hapus tmp.
  /// - Jangan pernah menghapus tmp yang merupakan satu-satunya salinan.
  static Future<void> recoverOrphanTmpFiles(Directory directory) async {
    if (!await directory.exists()) return;

    final entities = await directory.list(recursive: true, followLinks: false).toList();
    final tmpFiles = entities.whereType<File>().where((f) => f.path.endsWith('.tmp')).toList();
    if (tmpFiles.isEmpty) return;

    final Map<String, List<File>> tmpByTarget = {};
    for (final tmp in tmpFiles) {
      final targetPath = resolveTargetFromTmpPath(tmp.path);
      if (targetPath != null) {
        tmpByTarget.putIfAbsent(targetPath, () => []).add(tmp);
      }
    }

    for (final entry in tmpByTarget.entries) {
      final targetPath = entry.key;
      final tmps = entry.value;
      final targetFile = File(targetPath);

      if (await targetFile.exists()) {
        for (final tmp in tmps) {
          try {
            await tmp.delete();
          } catch (_) {}
        }
      } else {
        tmps.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        bool promoted = false;
        for (final tmp in tmps) {
          if (!promoted) {
            try {
              final text = await tmp.readAsString(encoding: utf8);
              json.decode(text); // Validasi JSON
              try {
                await tmp.rename(targetFile.path);
              } catch (_) {
                await tmp.copy(targetFile.path);
                try {
                  await tmp.delete();
                } catch (_) {}
              }
              promoted = true;
            } catch (_) {
              // Jika tidak valid dan merupakan satu-satunya salinan, jangan hapus!
            }
          } else {
            // Target sudah berhasil dipromosikan dari tmp yang valid, tmp lainnya dibersihkan
            try {
              await tmp.delete();
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Memulihkan file *.tmp yatim untuk berkas target spesifik [targetFile].
  static Future<void> recoverTargetOrphans(File targetFile) async {
    final parent = targetFile.parent;
    if (!await parent.exists()) return;
    final basename = p.basename(targetFile.path);
    final entities = await parent.list(followLinks: false).toList();
    final tmps = entities.whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith(basename) && name.endsWith('.tmp');
    }).toList();

    if (tmps.isEmpty) return;

    if (await targetFile.exists()) {
      for (final tmp in tmps) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } else {
      tmps.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      bool promoted = false;
      for (final tmp in tmps) {
        if (!promoted) {
          try {
            final text = await tmp.readAsString(encoding: utf8);
            json.decode(text);
            try {
              await tmp.rename(targetFile.path);
            } catch (_) {
              await tmp.copy(targetFile.path);
              try {
                await tmp.delete();
              } catch (_) {}
            }
            promoted = true;
          } catch (_) {}
        } else {
          try {
            await tmp.delete();
          } catch (_) {}
        }
      }
    }
  }
}
