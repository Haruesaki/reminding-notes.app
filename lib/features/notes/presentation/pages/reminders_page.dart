import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explorer/domain/entities/entities.dart';
import '../../domain/services/reminder_calculator.dart';
import '../cubit/deadline_calendar_cubit.dart';
import '../cubit/deadline_calendar_state.dart';

class RemindersPage extends StatefulWidget {
  final DateTime Function()? nowProvider;

  const RemindersPage({super.key, this.nowProvider});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<DeadlineCalendarCubit>()
            .loadDeadlines(nowOverride: widget.nowProvider?.call());
      }
    });
  }

  Color _getRemainingTimeColor(DateTime deadline, DateTime now) {
    final status = ReminderCalculator.calculateDateDeadlineStatus(
      targetDate: deadline,
      now: now,
      hasUndoneTask: true,
    );
    if (status == DeadlineBadgeStatus.urgent) {
      return AppColors.deadlineUrgent; // #E5484D
    } else if (status == DeadlineBadgeStatus.relaxed) {
      return AppColors.deadlineRelaxed; // #30A46C
    }
    return AppColors.textSecondary; // netral 3-7 hari
  }

  void _openFile(DeadlineItem item) {
    if (item.fileType == 'list') {
      context.push('/list/${item.fileId}').then((_) {
        if (mounted) {
          context.read<DeadlineCalendarCubit>().loadDeadlines();
        }
      });
    } else {
      context.push('/note/${item.fileId}').then((_) {
        if (mounted) {
          context.read<DeadlineCalendarCubit>().loadDeadlines();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowProvider?.call() ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Pengingat',
          style: AppTypography.heading2.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocBuilder<DeadlineCalendarCubit, DeadlineCalendarState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.dateChipActive),
            );
          }

          final deadlines = state.upcomingDeadlines;
          if (deadlines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_outlined,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada pengingat deadline',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenMargin,
              vertical: 12,
            ),
            itemCount: deadlines.length,
            separatorBuilder: (_, _) => const Divider(
              color: AppColors.borderLight,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = deadlines[index];
              final timeColor = _getRemainingTimeColor(item.at, now);
              final remainingText =
                  ReminderCalculator.calculateRemainingTimeText(now, item.at);
              final dateBadge =
                  ReminderCalculator.formatDeadlineBadge(item.at);

              return InkWell(
                onTap: () => _openFile(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 12),
                        child: Icon(
                          item.fileType == 'list'
                              ? Icons.check_box_outline_blank_rounded
                              : Icons.article_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.taskText.isEmpty
                                  ? '(Tugas tanpa judul)'
                                  : item.taskText,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.fileTitle.isEmpty
                                  ? 'Catatan'
                                  : item.fileTitle,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            dateBadge,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            remainingText,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: timeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
