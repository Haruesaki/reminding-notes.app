import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
  final QuillController controller;
  final bool forceVisible;

  const FormattingToolbar({
    super.key,
    required this.controller,
    this.forceVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selection = controller.selection;
        final hasSelection = forceVisible ||
            (selection.isValid &&
                !selection.isCollapsed &&
                selection.end > selection.start);

        if (!hasSelection) {
          return const SizedBox.shrink();
        }

        final style = controller.getSelectionStyle().attributes;
        final isBold = style.containsKey(Attribute.bold.key);
        final isItalic = style.containsKey(Attribute.italic.key);
        final isUnderline = style.containsKey(Attribute.underline.key);
        final isHeaderOrList = style.containsKey(Attribute.header.key) ||
            style.containsKey(Attribute.list.key);
        final alignVal = style[Attribute.align.key]?.value;
        final isJustify = alignVal == 'justify';
        final isLeft = alignVal == 'left' || (!style.containsKey(Attribute.align.key));
        final isCenter = alignVal == 'center';
        final isRight = alignVal == 'right';

        return Material(
          color: Colors.transparent,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
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
                  // B - Bold
                  _buildButton(
                    key: const Key('toolbar_bold'),
                    tooltip: 'Tebal',
                    isActive: isBold,
                    child: const Text(
                      'B',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      controller.formatSelection(
                        isBold ? Attribute.clone(Attribute.bold, null) : Attribute.bold,
                      );
                    },
                  ),
                  const SizedBox(width: 2),

                  // I - Italic
                  _buildButton(
                    key: const Key('toolbar_italic'),
                    tooltip: 'Miring',
                    isActive: isItalic,
                    child: const Text(
                      'I',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      controller.formatSelection(
                        isItalic ? Attribute.clone(Attribute.italic, null) : Attribute.italic,
                      );
                    },
                  ),
                  const SizedBox(width: 2),

                  // U - Underline
                  _buildButton(
                    key: const Key('toolbar_underline'),
                    tooltip: 'Garis bawah',
                    isActive: isUnderline,
                    child: const Text(
                      'U',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      controller.formatSelection(
                        isUnderline
                            ? Attribute.clone(Attribute.underline, null)
                            : Attribute.underline,
                      );
                    },
                  ),
                  const SizedBox(width: 2),

                  // T - Paragraph style popover
                  Builder(
                    builder: (btnContext) {
                      return _buildButton(
                        key: const Key('toolbar_typography'),
                        tooltip: 'Gaya paragraf',
                        isActive: isHeaderOrList,
                        child: const Text(
                          'T',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                        onTap: () => _showParagraphStyleMenu(btnContext),
                      );
                    },
                  ),
                  _buildDivider(),

                  // Rata penuh (Justify)
                  _buildButton(
                    key: const Key('toolbar_align_justify'),
                    tooltip: 'Rata penuh',
                    isActive: isJustify,
                    child: const Icon(Icons.format_align_justify_rounded, size: 19),
                    onTap: () {
                      controller.formatSelection(
                        isJustify
                            ? Attribute.clone(Attribute.align, null)
                            : Attribute.justifyAlignment,
                      );
                    },
                  ),
                  const SizedBox(width: 2),

                  // Rata kiri (Left)
                  _buildButton(
                    key: const Key('toolbar_align_left'),
                    tooltip: 'Rata kiri',
                    isActive: isLeft,
                    child: const Icon(Icons.format_align_left_rounded, size: 19),
                    onTap: () {
                      controller.formatSelection(Attribute.leftAlignment);
                    },
                  ),
                  const SizedBox(width: 2),

                  // Rata tengah (Center)
                  _buildButton(
                    key: const Key('toolbar_align_center'),
                    tooltip: 'Rata tengah',
                    isActive: isCenter,
                    child: const Icon(Icons.format_align_center_rounded, size: 19),
                    onTap: () {
                      controller.formatSelection(Attribute.centerAlignment);
                    },
                  ),
                  const SizedBox(width: 2),

                  // Rata kanan (Right)
                  _buildButton(
                    key: const Key('toolbar_align_right'),
                    tooltip: 'Rata kanan',
                    isActive: isRight,
                    child: const Icon(Icons.format_align_right_rounded, size: 19),
                    onTap: () {
                      controller.formatSelection(Attribute.rightAlignment);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showParagraphStyleMenu(BuildContext btnContext) async {
    final renderBox = btnContext.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? Size.zero;

    final selected = await showMenu<String>(
      context: btnContext,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 230,
        offset.dx + size.width,
        offset.dy,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF222222),
      items: const [
        PopupMenuItem(
          value: 'normal',
          child: Text(
            'Normal',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        PopupMenuItem(
          value: 'h1',
          child: Text(
            'Judul besar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'h2',
          child: Text(
            'Subjudul',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'ol',
          child: Text(
            'Daftar bernomor',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        PopupMenuItem(
          value: 'ul',
          child: Text(
            'Daftar poin',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );

    if (selected == null) return;

    switch (selected) {
      case 'normal':
        controller.formatSelection(Attribute.clone(Attribute.header, null));
        controller.formatSelection(Attribute.clone(Attribute.list, null));
        break;
      case 'h1':
        controller.formatSelection(Attribute.clone(Attribute.list, null));
        controller.formatSelection(Attribute.h1);
        break;
      case 'h2':
        controller.formatSelection(Attribute.clone(Attribute.list, null));
        controller.formatSelection(Attribute.h2);
        break;
      case 'ol':
        controller.formatSelection(Attribute.clone(Attribute.header, null));
        controller.formatSelection(Attribute.ol);
        break;
      case 'ul':
        controller.formatSelection(Attribute.clone(Attribute.header, null));
        controller.formatSelection(Attribute.ul);
        break;
    }
  }

  Widget _buildButton({
    required Key key,
    required String tooltip,
    required bool isActive,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final foregroundColor = isActive ? AppColors.textHighlightHandle : const Color(0xFFC0C0C0);
    final backgroundColor = isActive ? AppColors.formatToolbarActive : Colors.transparent;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: foregroundColor, size: 19),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 16,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF383838),
    );
  }
}
