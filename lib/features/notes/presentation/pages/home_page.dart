import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/name_sanitizer.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../bloc/note_list/note_list_bloc.dart';
import '../bloc/note_list/note_list_event.dart';
import '../bloc/note_list/note_list_state.dart';
import '../cubit/copy_move_cubit.dart';
import '../cubit/copy_move_state.dart';
import '../cubit/deadline_calendar_cubit.dart';
import '../../domain/services/file_share_service.dart';
import '../widgets/balloon_fab_menu.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/entry_context_menu.dart';
import '../widgets/folder_tile.dart';
import '../widgets/home_header.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';
import '../widgets/reorderable_card_wrapper.dart';
import 'editor_placeholder_page.dart';
import 'list_editor_page.dart';
import 'note_editor_page.dart';

class HomePage extends StatelessWidget {
  final String folderRelativePath;

  const HomePage({
    super.key,
    this.folderRelativePath = '',
  });

  static int getColumnCount(double screenWidth) {
    if (screenWidth < 600) {
      return 2;
    } else if (screenWidth <= 840) {
      return 3;
    } else {
      return 4;
    }
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Folder Baru', style: AppTypography.heading2),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nama folder',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama folder tidak boleh kosong';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final input = textController.text.trim();
                  final sanitized = NameSanitizer.sanitize(input);
                  context.read<NoteListBloc>().add(
                        CreateFolderEvent(
                          name: sanitized,
                          parentRelativePath: folderRelativePath,
                        ),
                      );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameFolderDialog(BuildContext context, Folder folder) async {
    final textController = TextEditingController(text: folder.name);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ganti Nama Folder', style: AppTypography.heading2),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nama folder baru',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama folder tidak boleh kosong';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final input = textController.text.trim();
                  final sanitized = NameSanitizer.sanitize(input);
                  context.read<NoteListBloc>().add(
                        RenameFolderEvent(
                          folderRelativePath: folder.relativePath,
                          newName: sanitized,
                        ),
                      );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteFolderDialog(BuildContext context, Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Folder', style: AppTypography.heading2),
          content: Text(
            'Hapus folder "${folder.name}" beserta seluruh isinya?',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deadlineUrgent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      context.read<NoteListBloc>().add(DeleteFolderEvent(folder));
    }
  }

  void _showFileMenu(BuildContext context, FileEntry file) {
    EntryContextMenu.showFileMenu(
      context: context,
      file: file,
      onShare: () async {
        try {
          await FileShareService.shareFile(file);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal membagikan berkas: $e')),
            );
          }
        }
      },
      onCopy: () {
        context.read<CopyMoveCubit>().startOperation(
              entry: file,
              operation: CopyMoveOperation.copy,
              sourceFolderRelativePath: folderRelativePath,
            );
      },
      onMove: () {
        context.read<CopyMoveCubit>().startOperation(
              entry: file,
              operation: CopyMoveOperation.move,
              sourceFolderRelativePath: folderRelativePath,
            );
      },
      onDelete: () {
        context.read<NoteListBloc>().add(DeleteNoteEvent(file.id));
      },
    );
  }

  void _showFolderMenu(BuildContext context, Folder folder) {
    EntryContextMenu.showFolderMenu(
      context: context,
      folder: folder,
      onRename: () => _showRenameFolderDialog(context, folder),
      onMove: () {
        context.read<CopyMoveCubit>().startOperation(
              entry: folder,
              operation: CopyMoveOperation.move,
              sourceFolderRelativePath: folderRelativePath,
            );
      },
      onDelete: () => _showDeleteFolderDialog(context, folder),
    );
  }

  void _executePaste(BuildContext context, CopyMoveActive activeState) {
    if (activeState.entry is Folder) {
      final entryRel = activeState.entry.relativePath.replaceAll(r'\', '/');
      final currentRel = folderRelativePath.replaceAll(r'\', '/');
      if (currentRel == entryRel || currentRel.startsWith('$entryRel/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.deadlineUrgent,
            content: Text(
              'Dilarang memindahkan folder ke dalam dirinya sendiri atau turunannya',
            ),
          ),
        );
        return;
      }
    }

    if (activeState.operation == CopyMoveOperation.move &&
        folderRelativePath == activeState.sourceFolderRelativePath) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${activeState.entryTitleOrName}" sudah berada di folder ini'),
        ),
      );
      context.read<CopyMoveCubit>().cancel();
      return;
    }

    if (activeState.operation == CopyMoveOperation.move) {
      context.read<NoteListBloc>().add(
            MoveEntryEvent(
              entry: activeState.entry,
              destinationFolderRelativePath: folderRelativePath,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil memindahkan ${activeState.entryTitleOrName}')),
      );
    } else {
      context.read<NoteListBloc>().add(
            CopyFileEvent(
              file: activeState.entry as FileEntry,
              destinationFolderRelativePath: folderRelativePath,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menyalin ${activeState.entryTitleOrName}')),
      );
    }
    context.read<CopyMoveCubit>().cancel();
  }

  Future<void> _openEditor(BuildContext context, String fileType) async {
    if (fileType == 'Page') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteEditorPage(
            folderRelativePath: folderRelativePath,
          ),
        ),
      );
      if (context.mounted) {
        try {
          context.read<DeadlineCalendarCubit>().loadDeadlines();
        } catch (_) {}
        context.read<NoteListBloc>().add(LoadNotes(folderRelativePath: folderRelativePath));
      }
      return;
    }

    if (fileType == 'List') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListEditorPage(
            folderRelativePath: folderRelativePath,
          ),
        ),
      );
      if (context.mounted) {
        try {
          context.read<DeadlineCalendarCubit>().loadDeadlines();
        } catch (_) {}
        context.read<NoteListBloc>().add(LoadNotes(folderRelativePath: folderRelativePath));
      }
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditorPlaceholderPage(
          fileType: fileType,
          folderRelativePath: folderRelativePath,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      context.read<NoteListBloc>().add(LoadNotes(folderRelativePath: folderRelativePath));
    }
  }

  Widget _buildFolderHeader(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final folderTitle = segments.isNotEmpty ? segments.last : path;
    final breadcrumb = segments.join(' / ');

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            folderTitle,
            style: AppTypography.heading1.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            breadcrumb,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFolder = folderRelativePath.isNotEmpty;
    final deadlineState = (() {
      try {
        return context.watch<DeadlineCalendarCubit>().state;
      } catch (_) {
        return null;
      }
    })();

    final copyMoveState = (() {
      try {
        return context.watch<CopyMoveCubit>().state;
      } catch (_) {
        return const CopyMoveInactive();
      }
    })();

    final isCopyMoveMode = copyMoveState is CopyMoveActive;
    final pendingEntryId =
        copyMoveState is CopyMoveActive ? copyMoveState.entry.id : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: BlocBuilder<NoteListBloc, NoteListState>(
              builder: (context, state) {
                DateTime? selectedDate;
                String searchQuery = '';
                HomeFilter currentFilter = HomeFilter.semua;
                List<Folder> folders = [];
                List<FileEntry> files = [];
                List<SearchResultItem>? searchResults;
                bool isSearching = false;
                bool isLoading = state is NoteListLoading;

                if (state is NoteListLoaded) {
                  selectedDate = state.selectedDate;
                  searchQuery = state.searchQuery;
                  currentFilter = state.currentFilter;
                  folders = state.folders;
                  files = state.files;
                  searchResults = state.searchResults;
                  isSearching = state.isSearching;
                }

                final isEmpty = isSearching
                    ? (searchResults?.isEmpty ?? true)
                    : (folders.isEmpty && files.isEmpty);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columnCount = getColumnCount(constraints.maxWidth);

                    return RefreshIndicator(
                      color: AppColors.textPrimary,
                      onRefresh: () async {
                        context.read<NoteListBloc>().add(LoadNotes(
                              date: selectedDate,
                              query: searchQuery,
                              filter: currentFilter,
                              folderRelativePath: folderRelativePath,
                            ));
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.screenMargin,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                const SizedBox(height: 12),
                                HomeHeader(
                                  searchQuery: searchQuery,
                                  showBackButton: isFolder,
                                  hasUrgentDeadline:
                                      deadlineState?.hasUrgentDeadline ?? false,
                                  isCopyMoveMode: isCopyMoveMode,
                                  onPasteTap: copyMoveState is CopyMoveActive
                                      ? () => _executePaste(
                                            context,
                                            copyMoveState,
                                          )
                                      : null,
                                  onBackTap: () => Navigator.of(context).maybePop(),
                                  onQueryChanged: (query) {
                                    context
                                        .read<NoteListBloc>()
                                        .add(SearchNotes(query));
                                  },
                                  onBurgerTap: () {
                                    // TODO: M9 - Buka drawer explorer / navigasi
                                  },
                                  onNotificationTap: () {
                                    context.push('/reminders').then((_) {
                                      if (context.mounted) {
                                        try {
                                          context
                                              .read<DeadlineCalendarCubit>()
                                              .loadDeadlines();
                                        } catch (_) {}
                                        context.read<NoteListBloc>().add(
                                              LoadNotes(
                                                folderRelativePath:
                                                    folderRelativePath,
                                              ),
                                            );
                                      }
                                    });
                                  },
                                ),
                                if (isFolder) ...[
                                  _buildFolderHeader(folderRelativePath),
                                ] else if (!isSearching) ...[
                                  const SizedBox(height: 18),
                                  DateSelectorStrip(
                                    selectedDate: selectedDate,
                                    dateColors: deadlineState?.dateColors,
                                    dateDotColors: deadlineState?.dateDotColors,
                                    onDateSelected: (date) {
                                      context
                                          .read<NoteListBloc>()
                                          .add(SelectDateFilter(date));
                                    },
                                  ),
                                ],
                                if (!isSearching) ...[
                                  const SizedBox(height: 16),
                                  EntryFilterChips(
                                    selectedFilter: currentFilter,
                                    onFilterSelected: (filter) {
                                      context
                                          .read<NoteListBloc>()
                                          .add(SelectFilterEvent(filter));
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ]),
                            ),
                          ),
                          if (isLoading)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            )
                          else if (isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: NotesEmptyState(
                                message: isSearching
                                    ? 'Tidak ada hasil untuk "$searchQuery"'
                                    : 'Belum ada catatan. Ketuk + untuk membuat.',
                              ),
                            )
                          else if (isSearching && searchResults != null)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.screenMargin,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildSearchResultsMasonry(
                                    context,
                                    searchResults,
                                    columnCount,
                                    pendingEntryId,
                                  ),
                                  const SizedBox(height: 96),
                                ]),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.screenMargin,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  if (folders.isNotEmpty) ...[
                                    _buildFoldersGrid(
                                      context,
                                      folders,
                                      pendingEntryId,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (files.isNotEmpty)
                                    _buildFilesMasonry(
                                      context,
                                      folders,
                                      files,
                                      columnCount,
                                      pendingEntryId,
                                    ),
                                  const SizedBox(height: 96),
                                ]),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Bar Mode Salin / Pindahkan
          if (copyMoveState is CopyMoveActive)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.fabBackground,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          copyMoveState.operation == CopyMoveOperation.move
                              ? Icons.drive_file_move_outlined
                              : Icons.copy_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${copyMoveState.operation == CopyMoveOperation.move ? 'Memindahkan' : 'Menyalin'} "${copyMoveState.entryTitleOrName}"',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.read<CopyMoveCubit>().cancel();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Balloon FAB Menu
          if (!isCopyMoveMode)
            BalloonFabMenu(
              heroTag: folderRelativePath.isEmpty
                  ? 'add_note_fab'
                  : 'add_note_fab_$folderRelativePath',
              onSelectFolder: () => _showCreateFolderDialog(context),
              onSelectList: () => _openEditor(context, 'List'),
              onSelectPage: () => _openEditor(context, 'Page'),
            ),
        ],
      ),
    );
  }

  Widget _buildFoldersGrid(
    BuildContext context,
    List<Folder> folders,
    String? pendingEntryId,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: folders.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: AppConstants.folderTileHeight,
      ),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ReorderableCardWrapper<Folder>(
          key: ValueKey('folder_reorder_${folder.id}'),
          item: folder,
          onLongPressRelease: () => _showFolderMenu(context, folder),
          onReorder: (source, target) {
            final oldIdx = folders.indexOf(source);
            final newIdx = folders.indexOf(target);
            if (oldIdx != -1 && newIdx != -1) {
              final updated = List<Folder>.from(folders);
              final moved = updated.removeAt(oldIdx);
              updated.insert(newIdx, moved);
              context.read<NoteListBloc>().add(
                    ReorderEntriesEvent(
                      newOrder: updated.map((f) => f.id).toList(),
                      folderRelativePath: folderRelativePath,
                    ),
                  );
            }
          },
          child: FolderTile(
            folder: folder,
            isPendingOperation: folder.id == pendingEntryId,
            onLongPress: () => _showFolderMenu(context, folder),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => sl<NoteListBloc>()
                      ..add(LoadNotes(folderRelativePath: folder.relativePath)),
                    child: HomePage(folderRelativePath: folder.relativePath),
                  ),
                ),
              );
              if (context.mounted) {
                context
                    .read<NoteListBloc>()
                    .add(LoadNotes(folderRelativePath: folderRelativePath));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFilesMasonry(
    BuildContext context,
    List<Folder> currentFolders,
    List<FileEntry> files,
    int columnCount,
    String? pendingEntryId,
  ) {
    final columns =
        List.generate(columnCount, (_) => <({int index, FileEntry file})>[]);
    for (var i = 0; i < files.length; i++) {
      columns[i % columnCount].add((index: i, file: files[i]));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var colIdx = 0; colIdx < columnCount; colIdx++) ...[
          if (colIdx > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in columns[colIdx]) ...[
                  ReorderableCardWrapper<FileEntry>(
                    key: ValueKey('file_reorder_${item.file.id}'),
                    item: item.file,
                    canReorderWith: (source, target) =>
                        source.isFavorite == target.isFavorite,
                    onLongPressRelease: () => _showFileMenu(context, item.file),
                    onReorder: (source, target) {
                      final isFav = source.isFavorite;
                      final currentGroup =
                          files.where((f) => f.isFavorite == isFav).toList();
                      final oldIdx =
                          currentGroup.indexWhere((f) => f.id == source.id);
                      final newIdx =
                          currentGroup.indexWhere((f) => f.id == target.id);
                      if (oldIdx != -1 && newIdx != -1) {
                        final updatedGroup = List<FileEntry>.from(currentGroup);
                        final moved = updatedGroup.removeAt(oldIdx);
                        updatedGroup.insert(newIdx, moved);

                        final newOrder = [
                          ...currentFolders.map((f) => f.id),
                          if (isFav)
                            ...updatedGroup.map((f) => f.id)
                          else
                            ...files.where((f) => f.isFavorite).map((f) => f.id),
                          if (!isFav)
                            ...updatedGroup.map((f) => f.id)
                          else
                            ...files.where((f) => !f.isFavorite).map((f) => f.id),
                        ];

                        context.read<NoteListBloc>().add(
                              ReorderEntriesEvent(
                                newOrder: newOrder,
                                folderRelativePath: folderRelativePath,
                              ),
                            );
                      }
                    },
                    child: NoteCard(
                      note: item.file,
                      index: item.index,
                      isPendingOperation: item.file.id == pendingEntryId,
                      onLongPress: () => _showFileMenu(context, item.file),
                      onTap: () async {
                        if (item.file is ListFile) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ListEditorPage(
                                noteId: item.file.id,
                                folderRelativePath: folderRelativePath,
                                initialList: item.file as ListFile,
                              ),
                            ),
                          );
                        } else {
                          await context.push('/note/${item.file.id}');
                        }
                        if (context.mounted) {
                          try {
                            context
                                .read<DeadlineCalendarCubit>()
                                .loadDeadlines();
                          } catch (_) {}
                          context.read<NoteListBloc>().add(
                                LoadNotes(
                                  folderRelativePath: folderRelativePath,
                                ),
                              );
                        }
                      },
                      onTogglePin: () {
                        context.read<NoteListBloc>().add(
                              TogglePinEvent(
                                item.file.id,
                                !item.file.isFavorite,
                              ),
                            );
                      },
                      onDelete: () {
                        context.read<NoteListBloc>().add(
                              DeleteNoteEvent(item.file.id),
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResultsMasonry(
    BuildContext context,
    List<SearchResultItem> searchResults,
    int columnCount,
    String? pendingEntryId,
  ) {
    final columns = List.generate(
      columnCount,
      (_) => <({int index, SearchResultItem item})>[],
    );
    for (var i = 0; i < searchResults.length; i++) {
      columns[i % columnCount].add((index: i, item: searchResults[i]));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var colIdx = 0; colIdx < columnCount; colIdx++) ...[
          if (colIdx > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in columns[colIdx]) ...[
                  NoteCard(
                    note: row.item.file,
                    index: row.index,
                    breadcrumb: row.item.breadcrumb,
                    isPendingOperation: row.item.file.id == pendingEntryId,
                    onLongPress: () => _showFileMenu(context, row.item.file),
                    onTap: () async {
                      if (row.item.file is ListFile) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListEditorPage(
                              noteId: row.item.file.id,
                              folderRelativePath: folderRelativePath,
                              initialList: row.item.file as ListFile,
                            ),
                          ),
                        );
                      } else {
                        await context.push('/note/${row.item.file.id}');
                      }
                      if (context.mounted) {
                        try {
                          context
                              .read<DeadlineCalendarCubit>()
                              .loadDeadlines();
                        } catch (_) {}
                        context.read<NoteListBloc>().add(
                              LoadNotes(
                                folderRelativePath: folderRelativePath,
                              ),
                            );
                      }
                    },
                    onTogglePin: () {
                      context.read<NoteListBloc>().add(
                            TogglePinEvent(
                              row.item.file.id,
                              !row.item.file.isFavorite,
                            ),
                          );
                    },
                    onDelete: () {
                      context.read<NoteListBloc>().add(
                            DeleteNoteEvent(row.item.file.id),
                          );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
