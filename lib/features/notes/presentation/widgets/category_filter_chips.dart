import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const CategoryFilterChips({
    super.key,
    this.categories = const ['All Notes', 'Personal', 'Work', 'Ideas', 'Urgent'],
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isAllNotes = cat == 'All Notes';
          final isSelected = isAllNotes
              ? (selectedCategory == null || selectedCategory!.isEmpty)
              : selectedCategory == cat;

          return GestureDetector(
            onTap: () {
              if (isAllNotes) {
                onCategorySelected(null);
              } else {
                onCategorySelected(cat);
              }
            },
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
                  cat,
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
