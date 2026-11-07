import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

class NoteCard extends StatelessWidget {
  final FileEntry note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onTap,
    this.onTogglePin,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.cardColor(index);
    final dateString = DateFormat('MMM d, yyyy').format(note.updatedAt);
    final String contentText;
    if (note is PageFile) {
      contentText = (note as PageFile).plainText;
    } else if (note is ListFile) {
      contentText = (note as ListFile).tasks.map((t) => t.text).join(' • ');
    } else {
      contentText = '';
    }

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isFavorite) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onTogglePin,
                      child: const Icon(
                        Icons.favorite,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (contentText.isNotEmpty)
                Text(
                  contentText,
                  style: AppTypography.cardBody,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateString,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
