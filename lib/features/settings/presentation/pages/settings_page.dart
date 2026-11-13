import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/read_only_mode_banner.dart';
import '../../../backup/domain/repositories/backup_repository.dart';
import '../../../backup/domain/usecases/backup_usecases.dart';
import '../../../backup/presentation/bloc/backup_bloc.dart';
import '../../../notes/presentation/bloc/note_list/note_list_bloc.dart';
import '../../../notes/presentation/bloc/note_list/note_list_event.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBackupExpanded = false;

  late final BackupBloc _backupBloc;

  @override
  void initState() {
    super.initState();
    _backupBloc = sl<BackupBloc>();
  }

  @override
  void dispose() {
    _backupBloc.close();
    super.dispose();
  }

  void _handleExport() {
    _backupBloc.add(const BackupExportRequested());
  }

  void _handleImport() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (pickedFiles.isEmpty) {
      return;
    }

    final pickedFile = pickedFiles.first;
    final bytes = await pickedFile.readAsBytes();

    final tempExtractDirPath =
        'reminding_import_${DateTime.now().millisecondsSinceEpoch}';

    _backupBloc.add(BackupImportPickRequested(
      zipBytes: bytes,
      tempExtractDirPath: tempExtractDirPath,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BackupBloc>.value(
      value: _backupBloc,
      child: BlocListener<BackupBloc, BackupState>(
        listener: (context, state) async {
          switch (state.status) {
            case BackupStatus.error:
              _showErrorDialog(
                state.operation == BackupOperation.export
                    ? 'Gagal Export Backup'
                    : 'Gagal Impor Backup',
                state.error ?? 'Terjadi kesalahan yang tidak diketahui.',
              );
              break;
            case BackupStatus.success:
              if (state.operation == BackupOperation.export) {
                final bytes = _backupBloc.lastExportBytes;
                if (bytes != null && context.mounted) {
                  final now = DateTime.now();
                  final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(now);
                  final defaultFileName = 'NotesBackup_$dateStr.zip';

                  final resultUri = await FilePicker.saveFile(
                    dialogTitle: 'Simpan Backup Notes',
                    fileName: defaultFileName,
                    bytes: bytes,
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
                }
              } else {
                context.read<NoteListBloc>().add(const LoadNotes());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impor data backup berhasil selesai.'),
                    backgroundColor: AppColors.textPrimary,
                  ),
                );
              }
              break;
            default:
              break;
          }
        },
        child: Scaffold(
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
          body: BlocBuilder<BackupBloc, BackupState>(
            builder: (context, state) {
              final isLoading = state.status == BackupStatus.busy;

              return Column(
                children: [
                  const ReadOnlyModeBanner(),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          children: [
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
                                  ClipRect(
                                    child: AnimatedSize(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeInOut,
                                      child: _isBackupExpanded
                                          ? Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
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
                                                    onTap: isLoading ? null : _handleExport,
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
                                                    onTap: isLoading ? null : _handleImport,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            if (state.status == BackupStatus.success &&
                                state.operation == BackupOperation.import &&
                                state.inspection != null)
                              _buildImportModeDialog(state),
                          ],
                        ),
                        if (isLoading)
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
                                      state.message ?? 'Sedang memproses...',
                                      style: AppTypography.body,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImportModeDialog(BackupState state) {
    final inspection = state.inspection!;
    return Container(
      color: Colors.black54,
      child: AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pilih Mode Impor', style: AppTypography.heading2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ditemukan ${inspection.manifest.counts['notes'] ?? 0} catatan, ${inspection.manifest.counts['folders'] ?? 0} folder, dan ${inspection.manifest.counts['tones'] ?? 0} nada.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (ctx, setState) {
                ImportMode currentSelection = ImportMode.merge;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => currentSelection = ImportMode.merge),
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
                      onTap: () async {
                        final confirmed = await _showReplaceAllConfirmDialog();
                        if (!confirmed) return;
                        _backupBloc.add(const BackupImportModeSelected(ImportMode.replaceAll));
                        Navigator.of(context).pop();
                      },
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
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _backupBloc.add(const BackupImportCancelled());
              Navigator.of(context).pop();
            },
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _backupBloc.add(const BackupImportModeSelected(ImportMode.merge));
              Navigator.of(context).pop();
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
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
}
