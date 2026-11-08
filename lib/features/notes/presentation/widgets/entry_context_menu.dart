import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explorer/domain/entities/entities.dart';

class EntryContextMenu {
  static Future<void> showFileMenu({
    required BuildContext context,
    required FileEntry file,
    required VoidCallback onShare,
    required VoidCallback onCopy,
    required VoidCallback onMove,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    file.title.isNotEmpty ? file.title : 'Tanpa judul',
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
                  title: const Text('Bagikan', style: AppTypography.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    onShare();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined, color: AppColors.textPrimary),
                  title: const Text('Salin file', style: AppTypography.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCopy();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined, color: AppColors.textPrimary),
                  title: const Text('Pindahkan file', style: AppTypography.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMove();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.deadlineUrgent),
                  title: const Text(
                    'Hapus',
                    style: TextStyle(
                      color: AppColors.deadlineUrgent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showFolderMenu({
    required BuildContext context,
    required Folder folder,
    required VoidCallback onRename,
    required VoidCallback onMove,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    folder.name,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                  title: const Text('Ganti nama', style: AppTypography.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRename();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined, color: AppColors.textPrimary),
                  title: const Text('Pindahkan', style: AppTypography.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMove();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.deadlineUrgent),
                  title: const Text(
                    'Hapus',
                    style: TextStyle(
                      color: AppColors.deadlineUrgent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
