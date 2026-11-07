import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class DateSelectorStrip extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DateSelectorStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // 3 days back, 10 days ahead
    final days = List.generate(14, (i) {
      final base = DateTime(today.year, today.month, today.day);
      return base.add(Duration(days: i - 3));
    });

    return SizedBox(
      height: AppConstants.dateChipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppConstants.dateChipSpacing),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selectedDate != null &&
              selectedDate!.year == day.year &&
              selectedDate!.month == day.month &&
              selectedDate!.day == day.day;

          final weekdayName = DateFormat('E').format(day); // e.g., Thu
          final dayNumber = DateFormat('d').format(day); // e.g., 22

          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: AppConstants.dateChipWidth,
              height: AppConstants.dateChipHeight,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.dateChipActive
                    : AppColors.background,
                borderRadius:
                    BorderRadius.circular(AppConstants.dateChipRadius),
                border: isSelected
                    ? null
                    : Border.all(color: AppColors.dateChipInactiveBorder, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayName,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.dateChipActiveText
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dayNumber,
                    style: AppTypography.title.copyWith(
                      color: isSelected
                          ? AppColors.dateChipActiveText
                          : AppColors.dateChipInactiveText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
