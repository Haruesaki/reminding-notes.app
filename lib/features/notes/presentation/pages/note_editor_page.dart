import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../bloc/note_editor/note_editor_bloc.dart';
import '../bloc/note_editor/note_editor_event.dart';
import '../bloc/note_editor/note_editor_state.dart';
import '../widgets/formatting_toolbar.dart';

class NoteEditorPage extends StatelessWidget {
  final String? noteId;
  final String folderRelativePath;
  final PageFile? initialPage;

  const NoteEditorPage({
    super.key,
    this.noteId,
    this.folderRelativePath = '',
    this.initialPage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NoteEditorBloc>()
        ..add(InitializeNote(
          noteId: (noteId == null || noteId == 'new') ? null : noteId,
          folderRelativePath: folderRelativePath,
          initialPage: initialPage,
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

class _NoteEditorViewState extends State<_NoteEditorView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;

  Timer? _debounceTimer;
  bool _isConvertingAutoList = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController();
    _quillController = QuillController.basic();

    _titleController.addListener(_onTextChanged);
    _quillController.addListener(_onQuillChanged);

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveImmediate();
    }
  }

  void _onTextChanged() {
    _scheduleAutoSave();
  }

  void _onQuillChanged() {
    _checkAutoList();
    _scheduleAutoSave();
  }

  void _checkAutoList() {
    if (_isConvertingAutoList) return;
    final selection = _quillController.selection;
    if (!selection.isCollapsed || selection.baseOffset < 2) return;

    final offset = selection.baseOffset;
    final text = _quillController.document.toPlainText();
    if (offset > text.length) return;

    if (offset > 0 && text[offset - 1] != ' ') return;

    final before = text.substring(0, offset);
    final lastNewline = before.lastIndexOf('\n', offset - 2);
    final lineStart = lastNewline == -1 ? 0 : lastNewline + 1;
    final linePrefix = text.substring(lineStart, offset);

    if (linePrefix == '1. ') {
      _isConvertingAutoList = true;
      _quillController.replaceText(lineStart, 3, '', null);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: lineStart),
        ChangeSource.local,
      );
      _quillController.formatSelection(Attribute.ol);
      _isConvertingAutoList = false;
    } else if (linePrefix == '- ') {
      _isConvertingAutoList = true;
      _quillController.replaceText(lineStart, 2, '', null);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: lineStart),
        ChangeSource.local,
      );
      _quillController.formatSelection(Attribute.ul);
      _isConvertingAutoList = false;
    }
  }

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveImmediate();
    });
  }

  void _saveImmediate() {
    _debounceTimer?.cancel();
    if (!mounted) return;

    final title = _titleController.text;
    final deltaOps = _quillController.document.toDelta().toJson();
    final plainText = _quillController.document.toPlainText().trimRight();

    if (title.trim().isEmpty && plainText.trim().isEmpty) {
      return;
    }

    final bloc = context.read<NoteEditorBloc>();
    bloc.add(UpdateTitle(title));
    bloc.add(UpdateContentDelta(content: deltaOps, plainText: plainText));
    bloc.add(const SaveNoteEvent());
  }

  void _onExit() {
    _debounceTimer?.cancel();
    final title = _titleController.text;
    final plainText = _quillController.document.toPlainText().trimRight();

    if (title.trim().isEmpty && plainText.trim().isEmpty) {
      context.read<NoteEditorBloc>().add(const DiscardEmptyNoteEvent());
    } else {
      _saveImmediate();
    }
  }

  void _copyPlainText() async {
    final plainText = _quillController.document.toPlainText().trimRight();
    final title = _titleController.text.trim();
    final textToCopy = title.isNotEmpty ? '$title\n\n$plainText' : plainText;

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disalin'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleFavorite() {
    _heartAnimController.forward(from: 0.0);
    context.read<NoteEditorBloc>().add(const TogglePinInEditor());
  }

  void _handleBack() {
    _onExit();
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _quillController.removeListener(_onQuillChanged);
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteEditorBloc, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorLoaded && !_isInitialized) {
          _isInitialized = true;
          if (_titleController.text != state.note.title) {
            _titleController.text = state.note.title;
          }

          if (state.note.content.isNotEmpty) {
            try {
              final doc = Document.fromJson(state.note.content);
              _quillController.document = doc;
            } catch (_) {}
          } else if (state.note.plainText.isNotEmpty) {
            _quillController.document.insert(0, state.note.plainText);
          }
          setState(() {});
        }
      },
      builder: (context, state) {
        if (state is NoteEditorLoading || state is NoteEditorInitial) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary),
            ),
          );
        }

        if (state is NoteEditorError) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  final nav = Navigator.maybeOf(context);
                  if (nav != null && nav.canPop()) {
                    nav.pop();
                  }
                },
              ),
            ),
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as NoteEditorLoaded;
        final isFavorite = loaded.note.isFavorite;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _onExit();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Stack(
                children: [
                  // Main Scrollable Area
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.screenMargin,
                            68,
                            AppConstants.screenMargin,
                            100,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title (Large, Bold, Multi-line)
                              TextField(
                                key: const Key('note_title_input'),
                                controller: _titleController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111111),
                                  height: 1.15,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Tanpa judul',
                                  hintStyle: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8A8A8A),
                                    height: 1.15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Rich Text Quill Editor
                              QuillEditor.basic(
                                controller: _quillController,
                                focusNode: _editorFocusNode,
                                config: const QuillEditorConfig(
                                  scrollable: false,
                                  autoFocus: false,
                                  expands: false,
                                  placeholder: 'Mulai mengetik...',
                                ),
                              ),

                              // Bottom tap target for focusing editor
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _editorFocusNode.requestFocus(),
                                child: const SizedBox(height: 200),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pinned Header & Gradient Scroll Fade
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          height: 56,
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Row(
                                children: [
                              IconButton(
                                key: const Key('editor_back_button'),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF111111),
                                  size: 24,
                                ),
                                tooltip: 'Kembali',
                                onPressed: _handleBack,
                              ),
                              const Spacer(),
                              // Clipboard action
                              IconButton(
                                key: const Key('editor_copy_button'),
                                icon: const Icon(
                                  Icons.content_copy_rounded,
                                  color: Color(0xFF111111),
                                  size: 22,
                                ),
                                tooltip: 'Salin teks',
                                onPressed: _copyPlainText,
                              ),
                              // Favorite heart toggle with pop animation
                              ScaleTransition(
                                scale: _heartScaleAnimation,
                                child: IconButton(
                                  key: const Key('editor_favorite_button'),
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFavorite
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFF111111),
                                    size: 24,
                                  ),
                                  tooltip: isFavorite ? 'Hapus favorit' : 'Favorit',
                                  onPressed: _toggleFavorite,
                                ),
                              ),
                              // Share action (placeholder for M8)
                              IconButton(
                                key: const Key('editor_share_button'),
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Color(0xFF111111),
                                  size: 22,
                                ),
                                tooltip: 'Bagikan',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Fitur bagikan akan hadir di M8'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Gradient fade below header (without BackdropFilter)
                        IgnorePointer(
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Format Toolbar (appears ONLY when text is selected)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Center(
                      child: FormattingToolbar(
                        controller: _quillController,
                      ),
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

