import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

enum FormatAction {
  bold,
  italic,
  underline,
  strikethrough,
  heading,
  bulletList,
  numberedList,
  checklist,
}

class FormattingToolbar extends StatelessWidget {
  final ValueChanged<FormatAction> onFormat;

  const FormattingToolbar({
    super.key,
    required this.onFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.formatToolbarHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.formatToolbarBackground,
        borderRadius: BorderRadius.circular(AppConstants.formatToolbarRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarItem(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onTap: () => onFormat(FormatAction.bold),
            ),
            _buildToolbarItem(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              onTap: () => onFormat(FormatAction.italic),
            ),
            _buildToolbarItem(
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              onTap: () => onFormat(FormatAction.underline),
            ),
            _buildToolbarItem(
              icon: Icons.format_strikethrough,
              tooltip: 'Strikethrough',
              onTap: () => onFormat(FormatAction.strikethrough),
            ),
            _buildDivider(),
            _buildToolbarItem(
              icon: Icons.title,
              tooltip: 'Heading',
              onTap: () => onFormat(FormatAction.heading),
            ),
            _buildToolbarItem(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet List',
              onTap: () => onFormat(FormatAction.bulletList),
            ),
            _buildToolbarItem(
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered List',
              onTap: () => onFormat(FormatAction.numberedList),
            ),
            _buildToolbarItem(
              icon: Icons.check_box_outlined,
              tooltip: 'Checklist',
              onTap: () => onFormat(FormatAction.checklist),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white24,
    );
  }
}
