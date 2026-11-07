import 'package:flutter/material.dart';
import 'app_colors.dart';

/// App typography tokens strictly adhering to PRD 4.3:
/// No explicit fontFamily; relies on system default font.
class AppTypography {
  // Base styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Search bar
  static const TextStyle search = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Home cards
  static const TextStyle cardTitle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardBody = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // Date strip
  static const TextStyle dateChipDay = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle dateChipNumber = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle dateChipMonth = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
  );

  // Filter chips
  static const TextStyle filterChipActive = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    color: AppColors.filterChipActiveText,
  );

  static const TextStyle filterChipInactive = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AppColors.filterChipInactiveText,
  );

  // Editor
  static const TextStyle editorTitle = TextStyle(
    fontSize: 40.0,
    fontWeight: FontWeight.w700,
    color: AppColors.editorTitle,
    height: 1.1,
  );

  static const TextStyle editorBody = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w400,
    color: AppColors.editorBody,
    height: 1.5,
  );
}
