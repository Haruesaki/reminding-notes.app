import 'dart:ui';
import 'package:equatable/equatable.dart';
import '../../../explorer/domain/entities/entities.dart';

class DeadlineCalendarState extends Equatable {
  /// Peta tanggal (midnight) -> warna fill chip (merah / hijau / null untuk netral)
  final Map<DateTime, Color> dateColors;

  /// Peta tanggal (midnight) -> warna titik indikator saat chip terpilih
  final Map<DateTime, Color> dateDotColors;

  /// Semua deadline mendatang yang belum selesai, urut terdekat
  final List<DeadlineItem> upcomingDeadlines;

  /// Indikator titik hijau di lonceng (ada deadline belum selesai dalam <= 3 hari)
  final bool hasUrgentDeadline;

  /// Status loading
  final bool isLoading;

  const DeadlineCalendarState({
    this.dateColors = const {},
    this.dateDotColors = const {},
    this.upcomingDeadlines = const [],
    this.hasUrgentDeadline = false,
    this.isLoading = false,
  });

  DeadlineCalendarState copyWith({
    Map<DateTime, Color>? dateColors,
    Map<DateTime, Color>? dateDotColors,
    List<DeadlineItem>? upcomingDeadlines,
    bool? hasUrgentDeadline,
    bool? isLoading,
  }) {
    return DeadlineCalendarState(
      dateColors: dateColors ?? this.dateColors,
      dateDotColors: dateDotColors ?? this.dateDotColors,
      upcomingDeadlines: upcomingDeadlines ?? this.upcomingDeadlines,
      hasUrgentDeadline: hasUrgentDeadline ?? this.hasUrgentDeadline,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        dateColors,
        dateDotColors,
        upcomingDeadlines,
        hasUrgentDeadline,
        isLoading,
      ];
}
