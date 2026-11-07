import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../../../explorer/domain/repositories/explorer_repository.dart';
import '../../domain/services/reminder_calculator.dart';
import 'deadline_calendar_state.dart';

class DeadlineCalendarCubit extends Cubit<DeadlineCalendarState> {
  final ExplorerRepository repository;
  final DateTime Function() _nowProvider;

  // Token warna deadline PRD 7.1 & AppColors
  static const Color colorUrgent = AppColors.deadlineUrgent; // #E5484D
  static const Color colorRelaxed = AppColors.deadlineRelaxed; // #30A46C
  static const Color colorNeutralDot = Color(0xFF9E9E9E);

  DeadlineCalendarCubit({
    required this.repository,
    DateTime Function()? nowProvider,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        super(const DeadlineCalendarState());

  /// Helper statis murni untuk kalkulasi warna tanggal berdasarkan PRD 7.1:
  /// - selisih tanggal dari hari ini < 3 hari (termasuk overdue) = merah (#E5484D)
  /// - selisih tanggal dari hari ini > 7 hari = hijau (#30A46C)
  /// - 3-7 hari = netral (null)
  /// - task yang sudah dicentang tidak dihitung (hasUndoneTask == false -> null)
  static Color? calculateDateColor({
    required DateTime targetDate,
    required DateTime now,
    required bool hasUndoneTask,
  }) {
    final status = ReminderCalculator.calculateDateDeadlineStatus(
      targetDate: targetDate,
      now: now,
      hasUndoneTask: hasUndoneTask,
    );
    if (status == DeadlineBadgeStatus.urgent) {
      return colorUrgent;
    } else if (status == DeadlineBadgeStatus.relaxed) {
      return colorRelaxed;
    }
    return null;
  }

  /// Helper statis warna titik indikator saat chip tanggal terpilih:
  /// - bila tanggalnya punya deadline belum selesai, tambahkan titik kecil berwarna di bawah angka
  /// - < 3 hari = merah
  /// - > 7 hari = hijau
  /// - 3-7 hari = netral (abu-abu)
  /// - task yang sudah dicentang tidak dihitung (hasUndoneTask == false -> null)
  static Color? calculateDotColor({
    required DateTime targetDate,
    required DateTime now,
    required bool hasUndoneTask,
  }) {
    final status = ReminderCalculator.calculateDateDeadlineStatus(
      targetDate: targetDate,
      now: now,
      hasUndoneTask: hasUndoneTask,
    );
    if (status == DeadlineBadgeStatus.urgent) {
      return colorUrgent;
    } else if (status == DeadlineBadgeStatus.relaxed) {
      return colorRelaxed;
    } else if (status == DeadlineBadgeStatus.neutral) {
      return colorNeutralDot;
    }
    return null;
  }

  Future<void> loadDeadlines({DateTime? nowOverride}) async {
    emit(state.copyWith(isLoading: true));
    try {
      final allItems = await repository.getAllDeadlines();
      final now = nowOverride ?? _nowProvider();
      final nowMidnight = DateTime(now.year, now.month, now.day);

      // Task yang sudah dicentang (done: true) TIDAK dihitung (PRD 7.1)
      final activeDeadlines = allItems.where((d) => !d.done).toList();

      // Peta tanggal -> warna chip & dot
      final dateColors = <DateTime, Color>{};
      final dateDotColors = <DateTime, Color>{};

      // Kelompokkan per tanggal kalender (midnight)
      final grouped = <DateTime, List<DeadlineItem>>{};
      for (final item in activeDeadlines) {
        final key = DateTime(item.at.year, item.at.month, item.at.day);
        grouped.putIfAbsent(key, () => []).add(item);
      }

      for (final entry in grouped.entries) {
        final dateKey = entry.key;
        final color = calculateDateColor(
          targetDate: dateKey,
          now: now,
          hasUndoneTask: true,
        );
        if (color != null) {
          dateColors[dateKey] = color;
        }

        final dotColor = calculateDotColor(
          targetDate: dateKey,
          now: now,
          hasUndoneTask: true,
        );
        if (dotColor != null) {
          dateDotColors[dateKey] = dotColor;
        }
      }

      // Urutkan deadline mendatang yang belum selesai berdasarkan waktu terdekat
      final sortedUpcoming = List<DeadlineItem>.from(activeDeadlines)
        ..sort((a, b) => a.at.compareTo(b.at));

      // Titik hijau di lonceng muncul jika ada deadline belum selesai dalam <= 3 hari (PRD 7.1)
      // Termasuk overdue dan hari H sampai H+3 (selisih hari <= 3)
      final hasUrgent = activeDeadlines.any((d) {
        final dMidnight = DateTime(d.at.year, d.at.month, d.at.day);
        final diff = dMidnight.difference(nowMidnight).inDays;
        return diff <= 3;
      });

      emit(state.copyWith(
        dateColors: dateColors,
        dateDotColors: dateDotColors,
        upcomingDeadlines: sortedUpcoming,
        hasUrgentDeadline: hasUrgent,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
