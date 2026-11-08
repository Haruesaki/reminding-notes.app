import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explorer/domain/entities/folder.dart';

/// Compact folder tile widget displayed in a 2-column grid.
/// Conforms to Figma 2:14 and PRD Section 7.1.
class FolderTile extends StatelessWidget {
  final Folder folder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isPendingOperation;

  const FolderTile({
    super.key,
    required this.folder,
    this.onTap,
    this.onLongPress,
    this.isPendingOperation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPendingOperation ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
        height: AppConstants.folderTileHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.folderTileBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.folderTileBorder, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.folder_rounded,
              size: 26,
              color: AppColors.folderIcon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: AppTypography.folderTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${folder.order.length} ${folder.order.length == 1 ? "item" : "items"}',
                    style: AppTypography.folderSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
