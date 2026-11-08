import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';

class NoteCard extends StatefulWidget {
  final FileEntry note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final String? breadcrumb;
  final bool isPendingOperation;

  const NoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onTap,
    this.onTogglePin,
    this.onDelete,
    this.onLongPress,
    this.breadcrumb,
    this.isPendingOperation = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Pastel background based on note's colorIndex
    final bgColor = AppColors.cardColor(widget.note.colorIndex);
    final dateString = DateFormat('MMM d, yyyy').format(widget.note.updatedAt);

    Widget buildPreview() {
      final file = widget.note;
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
      key: Key(widget.note.id),
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
      onDismissed: (_) => widget.onDelete?.call(),
      child: Opacity(
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
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              ),
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.breadcrumb != null) ...[
                    Text(
                      widget.breadcrumb!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.note.title.isNotEmpty ? widget.note.title : 'Untitled',
                          style: AppTypography.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.note.isFavorite) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onTogglePin,
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
        ),
      ),
    );
  }
}
