import 'package:flutter/material.dart';

class AppColors {
  // Base
  static const Color background = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF131313);
  static const Color textSecondary = Color(0xFF7C7C7C);
  static const Color borderLight = Color(0xFFE6E6E6);
  static const Color searchFill = Color(0xFFF0F0F0);

  // FAB
  static const Color fabBackground = Color(0xFF070707);
  static const Color fabIcon = Color(0xFFFFFFFF);

  // Notification indicator
  static const Color notificationDot = Color(0xFF29FF8B);

  // Date strip
  static const Color dateChipActive = Color(0xFF181818);
  static const Color dateChipActiveText = Color(0xFFFFFFFF);
  static const Color dateChipInactiveBorder = Color(0xFFE6E6E6);
  static const Color dateChipInactiveText = Color(0xFF181818);

  // Filter chips
  static const Color filterChipActive = Color(0xFF0A0A0A);
  static const Color filterChipActiveText = Color(0xFFFFFFFF);
  static const Color filterChipInactiveText = Color(0xFF7C7C7C);
  static const Color filterChipInactiveBorder = Color(0xFFE2E2E2);

  // Editor
  static const Color editorTitle = Color(0xFF181818);
  static const Color editorBody = Color(0xFF292929);
  static const Color textHighlight = Color(0xFFFFF3C7);
  static const Color textHighlightHandle = Color(0xFFFFCB08);
  static const Color formatToolbarBackground = Color(0xFF181818);
  static const Color formatToolbarActive = Color(0xFF313131);

  // Deadlines (PRD 4.2 / Assumption 12)
  static const Color deadlineUrgent = Color(0xFFE5484D);
  static const Color deadlineRelaxed = Color(0xFF30A46C);

  // Pastel Card Palette (Figma: Home frames)
  static const List<Color> pastelCards = [
    Color(0xFFD8E8FB), // Blue
    Color(0xFFFCE89C), // Yellow
    Color(0xFFFFDAE3), // Pink
    Color(0xFFFFE9DD), // Peach
    Color(0xFFAFE8CA), // Green
    Color(0xFFFBFAD8), // Cream
  ];

  static Color cardColor(int index) =>
      pastelCards[index.abs() % pastelCards.length];
}
