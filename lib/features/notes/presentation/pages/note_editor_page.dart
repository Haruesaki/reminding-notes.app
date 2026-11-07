import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/note_editor/note_editor_bloc.dart';
import '../bloc/note_editor/note_editor_event.dart';
import '../bloc/note_editor/note_editor_state.dart';
import '../widgets/formatting_toolbar.dart';

class NoteEditorPage extends StatelessWidget {
  final String? noteId;

  const NoteEditorPage({super.key, this.noteId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NoteEditorBloc>()
        ..add(InitializeNote(
          noteId: (noteId == null || noteId == 'new') ? null : noteId,
        )),
      child: const _NoteEditorView(),
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  const _NoteEditorView();

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Undo / Redo stacks
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];
  bool _isUndoingOrRedoing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();

    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_isUndoingOrRedoing) return;
    final text = _contentController.text;
    if (_undoHistory.isEmpty || _undoHistory.last != text) {
      _undoHistory.add(text);
      if (_undoHistory.length > 30) _undoHistory.removeAt(0);
      _redoHistory.clear();
    }
  }

  void _undo() {
    if (_undoHistory.length > 1) {
      _isUndoingOrRedoing = true;
      final current = _undoHistory.removeLast();
      _redoHistory.add(current);
      final prev = _undoHistory.last;
      _contentController.value = TextEditingValue(
        text: prev,
        selection: TextSelection.collapsed(offset: prev.length),
      );
      context.read<NoteEditorBloc>().add(UpdateContent(prev));
      _scheduleAutoSave();
      _isUndoingOrRedoing = false;
      setState(() {});
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      _isUndoingOrRedoing = true;
      final next = _redoHistory.removeLast();
      _undoHistory.add(next);
      _contentController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      context.read<NoteEditorBloc>().add(UpdateContent(next));
      _scheduleAutoSave();
      _isUndoingOrRedoing = false;
      setState(() {});
    }
  }

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        context.read<NoteEditorBloc>().add(const SaveNoteEvent());
      }
    });
  }

  void _applyFormat(FormatAction action) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) return;

    final selectedText = text.substring(start, end);
    String replacement = '';
    int cursorOffset = 0;

    switch (action) {
      case FormatAction.bold:
        replacement = '**$selectedText**';
        cursorOffset = selectedText.isEmpty ? start + 2 : start + replacement.length;
        break;
      case FormatAction.italic:
        replacement = '*$selectedText*';
        cursorOffset = selectedText.isEmpty ? start + 1 : start + replacement.length;
        break;
      case FormatAction.underline:
        replacement = '<u>$selectedText</u>';
        cursorOffset = selectedText.isEmpty ? start + 3 : start + replacement.length;
        break;
      case FormatAction.strikethrough:
        replacement = '~~$selectedText~~';
        cursorOffset = selectedText.isEmpty ? start + 2 : start + replacement.length;
        break;
      case FormatAction.heading:
        replacement = '\n# $selectedText';
        cursorOffset = start + replacement.length;
        break;
      case FormatAction.bulletList:
        replacement = '\n• $selectedText';
        cursorOffset = start + replacement.length;
        break;
      case FormatAction.numberedList:
        replacement = '\n1. $selectedText';
        cursorOffset = start + replacement.length;
        break;
      case FormatAction.checklist:
        replacement = '\n- [ ] $selectedText';
        cursorOffset = start + replacement.length;
        break;
    }

    final newText = text.replaceRange(start, end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset.clamp(0, newText.length)),
    );
    context.read<NoteEditorBloc>().add(UpdateContent(newText));
    _scheduleAutoSave();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteEditorBloc, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorLoaded) {
          if (_titleController.text != state.note.title && !_titleController.value.composing.isValid) {
            _titleController.text = state.note.title;
          }
          if (_contentController.text != state.note.plainText && !_contentController.value.composing.isValid) {
            _contentController.text = state.note.plainText;
            if (_undoHistory.isEmpty) {
              _undoHistory.add(state.note.plainText);
            }
          }
        }
      },
      builder: (context, state) {
        if (state is NoteEditorLoading || state is NoteEditorInitial) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary),
            ),
          );
        }

        if (state is NoteEditorError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as NoteEditorLoaded;
        final note = loaded.note;
        final wordsCount = note.plainText.trim().isEmpty
            ? 0
            : note.plainText.trim().split(RegExp(r'\s+')).length;
        final updatedFormatted = DateFormat('MMM d, h:mm a').format(note.updatedAt);

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            context.read<NoteEditorBloc>().add(const SaveNoteEvent());
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                              onPressed: () {
                                context.read<NoteEditorBloc>().add(const SaveNoteEvent());
                                context.pop();
                              },
                            ),
                            const Spacer(),
                            // Auto-save status
                            Text(
                              loaded.isSaving
                                  ? 'Saving...'
                                  : loaded.isDirty
                                      ? 'Unsaved'
                                      : 'Saved',
                              style: AppTypography.caption.copyWith(
                                color: loaded.isSaving
                                    ? AppColors.textSecondary
                                    : (loaded.isDirty ? Colors.orange : AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Undo
                            IconButton(
                              icon: const Icon(Icons.undo, color: AppColors.textPrimary, size: 20),
                              tooltip: 'Undo',
                              onPressed: _undoHistory.length > 1 ? _undo : null,
                            ),
                            // Redo
                            IconButton(
                              icon: const Icon(Icons.redo, color: AppColors.textPrimary, size: 20),
                              tooltip: 'Redo',
                              onPressed: _redoHistory.isNotEmpty ? _redo : null,
                            ),
                            // Pin toggle
                            IconButton(
                              icon: Icon(
                                note.isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: note.isFavorite ? AppColors.textPrimary : AppColors.textSecondary,
                                size: 20,
                              ),
                              tooltip: note.isFavorite ? 'Unfavorite' : 'Favorite',
                              onPressed: () {
                                context.read<NoteEditorBloc>().add(const TogglePinInEditor());
                              },
                            ),
                          ],
                        ),
                      ),
                      // Metadata Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.screenMargin,
                        ),
                        child: Text(
                          '$updatedFormatted | $wordsCount words',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title TextField
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.screenMargin,
                        ),
                        child: TextField(
                          controller: _titleController,
                          style: AppTypography.heading1.copyWith(
                            fontSize: 26,
                            color: AppColors.editorTitle,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Title',
                            hintStyle: AppTypography.heading1.copyWith(
                              fontSize: 26,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            context.read<NoteEditorBloc>().add(UpdateTitle(val));
                            _scheduleAutoSave();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Content TextField
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.screenMargin,
                          ),
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            style: AppTypography.body.copyWith(
                              fontSize: 16,
                              color: AppColors.editorBody,
                              height: 1.5,
                            ),
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: 'Start typing...',
                              hintStyle: AppTypography.body.copyWith(
                                fontSize: 16,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 80),
                            ),
                            onChanged: (val) {
                              context.read<NoteEditorBloc>().add(UpdateContent(val));
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Floating Formatting Toolbar (Figma node 3:208)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: FormattingToolbar(
                      onFormat: _applyFormat,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
