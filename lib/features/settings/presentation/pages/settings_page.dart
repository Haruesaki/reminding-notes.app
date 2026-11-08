import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../core/di/injection_container.dart';
import '../../../../core/migration/migration_runner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../backup/data/services/backup_service.dart';
import '../../../backup/domain/models/backup_exceptions.dart';
import '../../../explorer/data/datasources/notes_index_manager.dart';
import '../../../notes/data/datasources/tones_local_data_source.dart';
import '../../../notes/data/services/notification_service.dart';
import '../../../notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../../notes/presentation/bloc/note_list/note_list_event.dart';

enum ImportMode { merge, replaceAll }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBackupExpanded = false;
  bool _isLoading = false;
  String _loadingMessage = '';

  void _showLoading(String message) {
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
  }

  void _hideLoading() {
    setState(() {
      _isLoading = false;
      _loadingMessage = '';
    });
  }

  Future<void> _handleExport() async {
    _showLoading('Menyiapkan file backup...');
    try {
      final notesDir = sl<Directory>(instanceName: 'notesDir');
      final assetsDir = sl<Directory>(instanceName: 'assetsDir');
      final backupService = sl<BackupService>();

      final zipBytes = await backupService.createBackup(
        notesDir: notesDir,
        assetsDir: assetsDir,
      );

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(now);
      final defaultFileName = 'NotesBackup_$dateStr.zip';

      _hideLoading();

      final resultUri = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup Notes',
        fileName: defaultFileName,
        bytes: zipBytes,
      );

      if (resultUri == null) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup berhasil disimpan: $defaultFileName'),
          backgroundColor: AppColors.textPrimary,
        ),
      );
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog('Gagal Export Backup', e.toString());
    }
  }

  Future<void> _handleImport() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final pickedFile = pickedFiles.first;
      final zipBytes = await pickedFile.readAsBytes();

      _showLoading('Memvalidasi file backup...');

      final tempExtractDir = Directory(
        p.join(Directory.systemTemp.path, 'reminding_import_${DateTime.now().millisecondsSinceEpoch}'),
      );
      final backupService = sl<BackupService>();

      final inspection = await backupService.inspectBackup(
        zipBytes: zipBytes,
        tempExtractDir: tempExtractDir,
      );

      _hideLoading();

      if (!mounted) return;

      // Tampilkan dialog pemilihan mode: Gabungkan vs Ganti semua
      final selectedMode = await _showImportModeDialog(inspection.manifest.counts);
      if (selectedMode == null) {
        // Dibatalkan oleh pengguna
        if (tempExtractDir.existsSync()) {
          try {
            tempExtractDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        return;
      }

      if (selectedMode == ImportMode.replaceAll) {
        final confirmed = await _showReplaceAllConfirmDialog();
        if (!confirmed) {
          if (tempExtractDir.existsSync()) {
            try {
              tempExtractDir.deleteSync(recursive: true);
            } catch (_) {}
          }
          return;
        }
      }

      _showLoading('Menerapkan data backup...');

      final notesDir = sl<Directory>(instanceName: 'notesDir');
      final assetsDir = sl<Directory>(instanceName: 'assetsDir');

      if (selectedMode == ImportMode.replaceAll) {
        final tempSafetyDir = Directory(
          p.join(Directory.systemTemp.path, 'reminding_safety_${DateTime.now().millisecondsSinceEpoch}'),
        );
        await backupService.executeReplaceAll(
          extractDir: tempExtractDir,
          notesDir: notesDir,
          assetsDir: assetsDir,
          tempSafetyDir: tempSafetyDir,
        );
      } else {
        await backupService.executeMerge(
          extractDir: tempExtractDir,
          notesDir: notesDir,
          assetsDir: assetsDir,
        );
      }

      // Bangun ulang indeks, daftarkan nada, dan jadwalkan ulang notifikasi (PRD 7.11)
      await sl<NotesIndexManager>().rebuildIndex(notesDir);
      await sl<TonesLocalDataSource>().reRegisterAllTones();
      await BackupService.rescheduleAllReminders(
        notesDir: notesDir,
        tonesDataSource: sl<TonesLocalDataSource>(),
        notificationService: sl<NotificationService>(),
      );

      // Bersihkan folder ekstraksi sementara
      if (tempExtractDir.existsSync()) {
        try {
          tempExtractDir.deleteSync(recursive: true);
        } catch (_) {}
      }

      _hideLoading();

      if (!mounted) return;
      // Refresh daftar catatan
      context.read<NoteListBloc>().add(const LoadNotes());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impor data backup berhasil selesai.'),
          backgroundColor: AppColors.textPrimary,
        ),
      );
    } on DangerousPathException catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog(
        'File Ditolak',
        'File backup mengandung path berbahaya yang berpotensi membahayakan sistem:\n${e.path}',
      );
    } on NewerSchemaVersionException catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog(
        'Versi Skema Tidak Didukung',
        'File backup dibuat dengan versi skema ${e.fileVersion}, sedangkan aplikasi saat ini hanya mendukung versi ${e.supportedVersion}.\nSilakan perbarui aplikasi.',
      );
    } on CorruptedBackupException catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog(
        'File Backup Rusak',
        'Proses impor dibatalkan karena terdapat file rusak atau checksum tidak cocok:\n\n'
            '${e.corruptedFiles.map((f) => '• $f').join('\n')}',
      );
    } on InvalidBackupException catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog('Backup Tidak Valid', e.message);
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      _showErrorDialog('Gagal Impor Backup', e.toString());
    }
  }

  Future<ImportMode?> _showImportModeDialog(Map<String, int> counts) async {
    ImportMode currentSelection = ImportMode.merge;

    return showDialog<ImportMode>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Pilih Mode Impor', style: AppTypography.heading2),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ditemukan ${counts['notes'] ?? 0} catatan, ${counts['folders'] ?? 0} folder, dan ${counts['tones'] ?? 0} nada.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 16),
                  RadioGroup<ImportMode>(
                    groupValue: currentSelection,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => currentSelection = val);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setDialogState(() => currentSelection = ImportMode.merge),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Radio<ImportMode>(
                                value: ImportMode.merge,
                                activeColor: AppColors.textPrimary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gabungkan (Default)', style: AppTypography.body),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tambahkan data ke catatan yang ada. Jika ada nama sama, akan dibuat salinan " (Impor)".',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => setDialogState(() => currentSelection = ImportMode.replaceAll),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Radio<ImportMode>(
                                value: ImportMode.replaceAll,
                                activeColor: AppColors.textPrimary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ganti semua', style: AppTypography.body),
                                    SizedBox(height: 2),
                                    Text(
                                      'Hapus seluruh catatan dan nada saat ini, lalu gantikan sepenuhnya dengan data backup.',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(currentSelection),
                  child: const Text('Lanjutkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showReplaceAllConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.deadlineUrgent),
              SizedBox(width: 8),
              Text('Ganti Semua Data?', style: AppTypography.heading2),
            ],
          ),
          content: const Text(
            'Peringatan: Seluruh catatan dan nada yang ada saat ini akan diganti sepenuhnya oleh data backup. Tindakan ini tidak dapat dibatalkan.',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deadlineUrgent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ganti Semua'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: AppTypography.heading2),
          content: SingleChildScrollView(
            child: Text(message, style: AppTypography.body),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup', style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Pengaturan', style: AppTypography.heading2),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Accordion Backup
              Container(
                decoration: BoxDecoration(
                  color: AppColors.folderTileBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _isBackupExpanded = !_isBackupExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.backup_outlined,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Backup',
                                style: AppTypography.body,
                              ),
                            ),
                            AnimatedRotation(
                              turns: _isBackupExpanded ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isBackupExpanded) ...[
                      const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(
                            Icons.upload_file_outlined,
                            color: AppColors.textPrimary,
                          ),
                          title: const Text('Export', style: AppTypography.body),
                          subtitle: const Text(
                            'Simpan semua data catatan dan nada ke file ZIP',
                            style: AppTypography.caption,
                          ),
                          onTap: _isLoading ? null : _handleExport,
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(
                            Icons.download_outlined,
                            color: AppColors.textPrimary,
                          ),
                          title: const Text('Import', style: AppTypography.body),
                          subtitle: const Text(
                            'Pulihkan data dari file ZIP backup',
                            style: AppTypography.caption,
                          ),
                          onTap: _isLoading ? null : _handleImport,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Teks Bantu Uninstall
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data terhapus bila aplikasi di-uninstall. Simpan file backup secara berkala ke penyimpanan eksternal atau cloud.',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: AppTypography.body,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
