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
    // Pastel background based on note's colorIndex
    final bgColor = AppColors.cardColor(note.colorIndex);
    final dateString = DateFormat('MMM d, yyyy').format(note.updatedAt);

    Widget buildPreview() {
      final file = note;
      if (file is PageFile) {
        if (file.plainText.trim().isEmpty) return const SizedBox.shrink();
        return Text(
          file.plainText,
          style: AppTypography.cardBody,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
        );
      } else if (file is ListFile) {
        if (file.tasks.isEmpty) return const SizedBox.shrink();
        final displayTasks = file.tasks.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: displayTasks.map((task) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    task.done
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 14,
                    color: task.done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.text,
                      style: AppTypography.cardBody.copyWith(
                        decoration:
                            task.done ? TextDecoration.lineThrough : null,
                        color: task.done
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }
      return const SizedBox.shrink();
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
            mainAxisSize: MainAxisSize.min,
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
              buildPreview(),
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
