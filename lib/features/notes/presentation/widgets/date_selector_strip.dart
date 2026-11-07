import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/deadline_calendar_cubit.dart';

class DateSelectorStrip extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, Color>? dateColors;
  final Map<DateTime, Color>? dateDotColors;

  const DateSelectorStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.dateColors,
    this.dateDotColors,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    // 14 hari berurutan, hari ini pertama dan bisa di-scroll horizontal (PRD 7.1)
    final days = List.generate(14, (i) {
      return todayMidnight.add(Duration(days: i));
    });

    // Ambil state peta warna dari cubit jika tersedia di context
    Map<DateTime, Color> activeDateColors = dateColors ?? const {};
    Map<DateTime, Color> activeDateDotColors = dateDotColors ?? const {};

    try {
      final cubit = BlocProvider.of<DeadlineCalendarCubit>(context);
      final cubitState = cubit.state;
      if (dateColors == null) {
        activeDateColors = cubitState.dateColors;
      }
      if (dateDotColors == null) {
        activeDateDotColors = cubitState.dateDotColors;
      }
    } catch (_) {
      // Jika cubit tidak disediakan di context (misal saat widget test terisolasi)
    }

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
          final dayKey = DateTime(day.year, day.month, day.day);

          final isSelected = selectedDate != null &&
              selectedDate!.year == day.year &&
              selectedDate!.month == day.month &&
              selectedDate!.day == day.day;

          final deadlineColor = activeDateColors[dayKey];
          final dotColor = activeDateDotColors[dayKey];

          final weekdayName = DateFormat('E').format(day); // e.g. Thu
          final dayNumber = DateFormat('d').format(day); // e.g. 22

          // Warna latar & teks chip
          final Color backgroundColor;
          final Color textColor;
          final Border? border;

          if (isSelected) {
            // Chip terpilih tetap hitam (PRD 7.1 point 2)
            backgroundColor = AppColors.dateChipActive;
            textColor = AppColors.dateChipActiveText; // Putih
            border = null;
          } else if (deadlineColor != null) {
            // Berwarna sesuai deadline (< 3 hari merah #E5484D, > 7 hari hijau #30A46C)
            backgroundColor = deadlineColor;
            textColor = Colors.white;
            border = Border.all(color: deadlineColor, width: 1);
          } else {
            // Netral / tanpa deadline
            backgroundColor = AppColors.background;
            textColor = AppColors.textSecondary;
            border = Border.all(
              color: AppColors.dateChipInactiveBorder,
              width: 1,
            );
          }

          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: AppConstants.dateChipWidth,
              height: AppConstants.dateChipHeight,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius:
                    BorderRadius.circular(AppConstants.dateChipRadius),
                border: border,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayName,
                    style: AppTypography.caption.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayNumber,
                    style: AppTypography.title.copyWith(
                      color: isSelected
                          ? AppColors.dateChipActiveText
                          : (deadlineColor != null
                              ? Colors.white
                              : AppColors.dateChipInactiveText),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isSelected && dotColor != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      key: const Key('selectedDateDot'),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
