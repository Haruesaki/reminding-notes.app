import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:reminding/features/explorer/domain/entities/entities.dart';
import '../bloc/note_list/note_list_bloc.dart';
import '../bloc/note_list/note_list_event.dart';
import '../bloc/note_list/note_list_state.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/home_header.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';
import '../widgets/notes_search_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<NoteListBloc, NoteListState>(
          builder: (context, state) {
            DateTime? selectedDate;
            String searchQuery = '';
            String? selectedCategory;
            List<FileEntry> notes = [];
            bool isLoading = state is NoteListLoading;

            if (state is NoteListLoaded) {
              selectedDate = state.selectedDate;
              searchQuery = state.searchQuery;
              selectedCategory = state.selectedCategory;
              notes = state.notes;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenMargin,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const HomeHeader(),
                  const SizedBox(height: 20),
                  DateSelectorStrip(
                    selectedDate: selectedDate,
                    onDateSelected: (date) {
                      context.read<NoteListBloc>().add(SelectDateFilter(date));
                    },
                  ),
                  const SizedBox(height: 20),
                  NotesSearchBar(
                    initialQuery: searchQuery,
                    onQueryChanged: (query) {
                      context.read<NoteListBloc>().add(SearchNotes(query));
                    },
                  ),
                  const SizedBox(height: 16),
                  CategoryFilterChips(
                    selectedCategory: selectedCategory,
                    onCategorySelected: (cat) {
                      context
                          .read<NoteListBloc>()
                          .add(SelectCategoryFilter(cat));
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.textPrimary,
                            ),
                          )
                        : notes.isEmpty
                            ? NotesEmptyState(
                                title: searchQuery.isNotEmpty
                                    ? 'No results found'
                                    : 'No notes here',
                                message: searchQuery.isNotEmpty
                                    ? 'Try adjusting your search terms'
                                    : 'Tap the button below to add your first note',
                              )
                            : RefreshIndicator(
                                color: AppColors.textPrimary,
                                onRefresh: () async {
                                  context.read<NoteListBloc>().add(LoadNotes(
                                        date: selectedDate,
                                        query: searchQuery,
                                        category: selectedCategory,
                                      ));
                                },
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(
                                    bottom: 90,
                                    top: 4,
                                  ),
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: notes.length,
                                  itemBuilder: (context, index) {
                                    final note = notes[index];
                                    return NoteCard(
                                      note: note,
                                      index: index,
                                      onTap: () async {
                                        await context.push('/note/${note.id}');
                                        if (context.mounted) {
                                          context
                                              .read<NoteListBloc>()
                                              .add(LoadNotes(
                                                date: selectedDate,
                                                query: searchQuery,
                                                category: selectedCategory,
                                              ));
                                        }
                                      },
                                      onTogglePin: () {
                                        context.read<NoteListBloc>().add(
                                              TogglePinEvent(
                                                note.id,
                                                !note.isFavorite,
                                              ),
                                            );
                                      },
                                      onDelete: () {
                                        context.read<NoteListBloc>().add(
                                              DeleteNoteEvent(note.id),
                                            );
                                      },
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
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
          onPressed: () async {
            await context.push('/note/new');
            if (context.mounted) {
              context.read<NoteListBloc>().add(const LoadNotes());
            }
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
}
