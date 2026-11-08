import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explorer/domain/entities/folder.dart';

/// Compact folder tile widget displayed in a 2-column grid.
/// Conforms to Figma 2:14 and PRD Section 7.1.
class FolderTile extends StatefulWidget {
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
  State<FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<FolderTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.isPendingOperation ? 0.5 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
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
                        widget.folder.name,
                        style: AppTypography.folderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.folder.order.length} ${widget.folder.order.length == 1 ? "item" : "items"}',
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
      ),
    );
  }
}
