import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../../../explorer/domain/usecases/explorer_usecases.dart';

/// Simple placeholder editor for List and Page (PRD 7.4).
/// Real editors are built in M4 and M5.
/// Rule PRD 7.4: Only creates and saves a new file if title or content is non-empty.
class EditorPlaceholderPage extends StatefulWidget {
  final String fileType; // 'Page' or 'List'
  final String folderRelativePath;

  const EditorPlaceholderPage({
    super.key,
    required this.fileType,
    this.folderRelativePath = '',
  });

  @override
  State<EditorPlaceholderPage> createState() => _EditorPlaceholderPageState();
}

class _EditorPlaceholderPageState extends State<EditorPlaceholderPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    if (_isSaving) return;
    _isSaving = true;

    final rawTitle = _titleController.text.trim();
    final rawContent = _contentController.text.trim();

    // PRD 7.4: If both title and content are empty, do not create or save a file
    if (rawTitle.isEmpty && rawContent.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    // PRD 7.4: Empty title defaults to 'Tanpa judul'
    final finalTitle = rawTitle.isEmpty ? 'Tanpa judul' : rawTitle;
    final now = DateTime.now();

    try {
      final targetFolder =
          widget.folderRelativePath.isEmpty ? null : widget.folderRelativePath;

      if (widget.fileType.toLowerCase() == 'list') {
        final lines =
            rawContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final tasks = lines.isEmpty
            ? [Task(id: const Uuid().v4(), text: finalTitle, done: false)]
            : lines
                .map((l) => Task(id: const Uuid().v4(), text: l.trim(), done: false))
                .toList();

        final listFile = ListFile(
          id: const Uuid().v4(),
          relativePath: '',
          title: finalTitle,
          tasks: tasks,
          colorIndex: 0,
          favoritedAt: null,
          createdAt: now,
          updatedAt: now,
        );

        await sl<SaveListUseCase>().call(SaveListParams(
          listFile: listFile,
          targetFolderRelativePath: targetFolder,
        ));
      } else {
        final page = PageFile(
          id: const Uuid().v4(),
          relativePath: '',
          title: finalTitle,
          plainText: rawContent,
          content: [
            {'insert': rawContent},
            {'insert': '\n'}
          ],
          colorIndex: 0,
          favoritedAt: null,
          createdAt: now,
          updatedAt: now,
        );

        await sl<SavePageUseCase>().call(SavePageParams(
          page: page,
          targetFolderRelativePath: targetFolder,
        ));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('SAVE ERROR: $e\n$st');
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleExit,
          ),
          title: Text(
            '${widget.fileType} Editor',
            style: AppTypography.title,
          ),
          actions: [
            TextButton(
              onPressed: _handleExit,
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenMargin,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.folderTileBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tipe: ${widget.fileType}',
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                style: AppTypography.heading2,
                decoration: const InputDecoration(
                  hintText: 'Judul catatan...',
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.borderLight),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: widget.fileType.toLowerCase() == 'list'
                        ? 'Daftar tugas (satu baris per item)...'
                        : 'Mulai menulis konten...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
