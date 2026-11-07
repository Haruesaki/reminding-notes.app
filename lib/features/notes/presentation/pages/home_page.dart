import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../bloc/note_list/note_list_bloc.dart';
import '../bloc/note_list/note_list_event.dart';
import '../bloc/note_list/note_list_state.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/folder_tile.dart';
import '../widgets/home_header.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static int getColumnCount(double screenWidth) {
    if (screenWidth < 600) {
      return 2;
    } else if (screenWidth <= 840) {
      return 3;
    } else {
      return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                            const SizedBox(height: 18),
                            DateSelectorStrip(
                              selectedDate: selectedDate,
                              onDateSelected: (date) {
                                context
                                    .read<NoteListBloc>()
                                    .add(SelectDateFilter(date));
                              },
                            ),
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
      floatingActionButton: SizedBox(
        width: AppConstants.fabSize,
        height: AppConstants.fabSize,
        child: FloatingActionButton(
          heroTag: 'add_note_fab',
          shape: const CircleBorder(),
          backgroundColor: AppColors.fabBackground,
          elevation: 4,
          onPressed: () {
            // TODO: M3 - Menu balon pembuatan catatan baru
          },
          child: const Icon(
            Icons.add,
            size: 30,
            color: AppColors.fabIcon,
          ),
        ),
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
          onTap: () {
            // TODO: M4 / M9 - Buka isi folder
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
                        context.read<NoteListBloc>().add(const LoadNotes());
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
