import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'notes_search_bar.dart';

/// Top bar for Home screen conforming to Figma 2:14 and PRD Section 7.1.
/// Layout: Burger icon (left) -> Search bar (center) -> Notification bell with green dot (right).
class HomeHeader extends StatelessWidget {
  final ValueChanged<String> onQueryChanged;
  final String searchQuery;
  final VoidCallback? onBurgerTap;
  final VoidCallback? onNotificationTap;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final bool hasUrgentDeadline;

  const HomeHeader({
    super.key,
    required this.onQueryChanged,
    this.searchQuery = '',
    this.onBurgerTap,
    this.onNotificationTap,
    this.showBackButton = false,
    this.onBackTap,
    this.hasUrgentDeadline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.searchBarHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Back button (in folder mode) or Burger button (Home)
          GestureDetector(
            onTap: showBackButton
                ? (onBackTap ?? () => Navigator.of(context).maybePop())
                : (onBurgerTap ??
                    () {
                      // TODO: M9 - Buka drawer navigasi explorer
                    }),
            child: Container(
              width: AppConstants.searchBarHeight,
              height: AppConstants.searchBarHeight,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Icon(
                showBackButton ? Icons.arrow_back_rounded : Icons.menu,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 2. Search bar
          Expanded(
            child: NotesSearchBar(
              initialQuery: searchQuery,
              onQueryChanged: onQueryChanged,
            ),
          ),
          const SizedBox(width: 10),
          // 3. Notification bell with green indicator dot
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: AppConstants.searchBarHeight,
              height: AppConstants.searchBarHeight,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_outlined,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                  if (hasUrgentDeadline)
                    Positioned(
                      top: 10,
                      right: 11,
                      child: Container(
                        key: const Key('bellUrgentDot'),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.notificationDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
