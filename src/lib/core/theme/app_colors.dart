import 'package:flutter/material.dart';

/// MPLAD SATYA color palette — restrained, government-grade, modern.
class AppColors {
  AppColors._();

  // ─── Primary Navy ───
  static const Color navy = Color(0xFF0A1929);
  static const Color navyLight = Color(0xFF132F4C);
  static const Color navyMedium = Color(0xFF1A3A5C);
  static const Color navySurface = Color(0xFF0F2744);

  // ─── Government Blue ───
  static const Color govBlue = Color(0xFF1565C0);
  static const Color govBlueDark = Color(0xFF0D47A1);
  static const Color govBlueLight = Color(0xFF42A5F5);
  static const Color govBlueSurface = Color(0xFFE3F2FD);

  // ─── India Tricolor Accents ───
  static const Color saffron = Color(0xFFFF9933);
  static const Color saffronDark = Color(0xFFE68A00);
  static const Color saffronLight = Color(0xFFFFAD5C);
  static const Color indiaGreen = Color(0xFF138808);
  static const Color indiaGreenLight = Color(0xFF4CAF50);

  // ─── Risk Palette ───
  static const Color riskCritical = Color(0xFFD32F2F);
  static const Color riskCriticalBg = Color(0xFFFDE8E8);
  static const Color riskCriticalDarkBg = Color(0xFF3D1515);
  static const Color riskHigh = Color(0xFFE65100);
  static const Color riskHighBg = Color(0xFFFFF3E0);
  static const Color riskHighDarkBg = Color(0xFF3D2200);
  static const Color riskMedium = Color(0xFFF9A825);
  static const Color riskMediumBg = Color(0xFFFFFDE7);
  static const Color riskMediumDarkBg = Color(0xFF3D3500);
  static const Color riskLow = Color(0xFF2E7D32);
  static const Color riskLowBg = Color(0xFFE8F5E9);
  static const Color riskLowDarkBg = Color(0xFF1B3D1E);

  // ─── Neutral / Surface ───
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F8);
  static const Color border = Color(0xFFE0E6ED);
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color divider = Color(0xFFE8ECF0);

  // ─── Dark Mode Surfaces ───
  static const Color darkBackground = Color(0xFF0A1929);
  static const Color darkSurface = Color(0xFF132F4C);
  static const Color darkSurfaceVariant = Color(0xFF1A3A5C);
  static const Color darkBorder = Color(0xFF1E4976);
  static const Color darkDivider = Color(0xFF1E3A5F);

  // ─── Text ───
  static const Color textPrimary = Color(0xFF1A2027);
  static const Color textSecondary = Color(0xFF5A6A7A);
  static const Color textTertiary = Color(0xFF8A97A8);
  static const Color textOnDark = Color(0xFFE8EDF2);
  static const Color textOnDarkSecondary = Color(0xFFB0BEC5);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Status ───
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1565C0);

  // ─── Misc ───
  static const Color shimmerBase = Color(0xFFE0E6ED);
  static const Color shimmerHighlight = Color(0xFFF5F7FA);
  static const Color darkShimmerBase = Color(0xFF1A3A5C);
  static const Color darkShimmerHighlight = Color(0xFF234E78);

  /// Get risk color based on score
  static Color riskColor(int score) {
    if (score >= 81) return riskCritical;
    if (score >= 61) return riskHigh;
    if (score >= 31) return riskMedium;
    return riskLow;
  }

  /// Get risk background color based on score (light theme)
  static Color riskBgColor(int score, {bool isDark = false}) {
    if (score >= 81) return isDark ? riskCriticalDarkBg : riskCriticalBg;
    if (score >= 61) return isDark ? riskHighDarkBg : riskHighBg;
    if (score >= 31) return isDark ? riskMediumDarkBg : riskMediumBg.withValues(alpha: 0.15);
    return isDark ? riskLowDarkBg : riskLowBg;
  }

  /// Get risk label from score
  static String riskLabel(int score) {
    if (score >= 81) return 'Critical';
    if (score >= 61) return 'High';
    if (score >= 31) return 'Medium';
    return 'Low';
  }

  /// Get risk icon based on score (accessibility: not color-only)
  static IconData riskIcon(int score) {
    if (score >= 81) return Icons.error;
    if (score >= 61) return Icons.warning_amber;
    if (score >= 31) return Icons.info_outline;
    return Icons.check_circle_outline;
  }
}
