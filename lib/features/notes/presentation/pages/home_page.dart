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
import '../widgets/balloon_fab_menu.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/folder_tile.dart';
import '../widgets/home_header.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';
import 'editor_placeholder_page.dart';
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
                bool isLoading = state is NoteListLoading;

                if (state is NoteListLoaded) {
                  selectedDate = state.selectedDate;
                  searchQuery = state.searchQuery;
                  currentFilter = state.currentFilter;
                  folders = state.folders;
                  files = state.files;
                }

                final isEmpty = folders.isEmpty && files.isEmpty;

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
                                  onBackTap: () => Navigator.of(context).maybePop(),
                                  onQueryChanged: (query) {
                                    context
                                        .read<NoteListBloc>()
                                        .add(SearchNotes(query));
                                  },
                                  onBurgerTap: () {
                                    // TODO: M9 - Buka drawer explorer / navigasi
                                  },
                                  onNotificationTap: () {},
                                ),
                                if (isFolder) ...[
                                  _buildFolderHeader(folderRelativePath),
                                ] else ...[
                                  const SizedBox(height: 18),
                                  DateSelectorStrip(
                                    selectedDate: selectedDate,
                                    onDateSelected: (date) {
                                      context
                                          .read<NoteListBloc>()
                                          .add(SelectDateFilter(date));
                                    },
                                  ),
                                ],
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
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: NotesEmptyState(
                                message:
                                    'Belum ada catatan. Ketuk + untuk membuat.',
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
                                    _buildFoldersGrid(context, folders),
                                    const SizedBox(height: 16),
                                  ],
                                  if (files.isNotEmpty)
                                    _buildFilesMasonry(
                                      context,
                                      files,
                                      columnCount,
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

          // Balloon FAB Menu
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

  Widget _buildFoldersGrid(BuildContext context, List<Folder> folders) {
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
        return FolderTile(
          folder: folder,
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
        );
      },
    );
  }

  Widget _buildFilesMasonry(
    BuildContext context,
    List<FileEntry> files,
    int columnCount,
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
                  NoteCard(
                    note: item.file,
                    index: item.index,
                    onTap: () async {
                      await context.push('/note/${item.file.id}');
                      if (context.mounted) {
                        context
                            .read<NoteListBloc>()
                            .add(LoadNotes(folderRelativePath: folderRelativePath));
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
