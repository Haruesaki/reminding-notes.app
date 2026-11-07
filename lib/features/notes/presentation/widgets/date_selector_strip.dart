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
    final todayMidnight = DateTime(today.year, today.month, today.day);

    // 6 day chips starting from today (PRD Section 7.1)
    final days = List.generate(6, (i) {
      return todayMidnight.add(Duration(days: i));
    });

    final activeDate = selectedDate ?? todayMidnight;

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
          final isSelected = activeDate.year == day.year &&
              activeDate.month == day.month &&
              activeDate.day == day.day;

          final weekdayName = DateFormat('E').format(day); // e.g. Thu
          final dayNumber = DateFormat('d').format(day); // e.g. 22

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
                    : Border.all(
                        color: AppColors.dateChipInactiveBorder,
                        width: 1,
                      ),
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
                  const SizedBox(height: 8),
                  Text(
                    dayNumber,
                    style: AppTypography.title.copyWith(
                      color: isSelected
                          ? AppColors.dateChipActiveText
                          : AppColors.dateChipInactiveText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // TODO: M7 - Indicator dot for deadline status (merah / hijau)
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
