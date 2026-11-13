import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/note_list/note_list_state.dart';

/// Filter chips for entry types conforming to PRD Section 7.1.
/// Filters: Semua, Favorit, Folder, List, Page.
class EntryFilterChips extends StatelessWidget {
  final HomeFilter selectedFilter;
  final ValueChanged<HomeFilter> onFilterSelected;

  const EntryFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    const filters = HomeFilter.values;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return GestureDetector(
            onTap: () => onFilterSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.filterChipActive
                    : AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.filterChipInactiveBorder,
                        width: 1,
                      ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: isSelected
                      ? AppTypography.filterChipActive
                      : AppTypography.filterChipInactive,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Backward compatibility alias
typedef CategoryFilterChips = EntryFilterChips;
