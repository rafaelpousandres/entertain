import 'package:flutter/material.dart';

/// Design tokens for the `entertain` light theme.
///
/// Names mirror the design system document; do not introduce ad-hoc hex
/// values elsewhere in the app — extend this file instead.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFFBF5EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF3E7CF);
  static const Color border = Color(0xFFEDE2CC);

  static const Color textPrimary = Color(0xFF412402);
  static const Color textSecondary = Color(0xFF8A7256);
  static const Color textTertiary = Color(0xFFA8946F);

  static const Color accent = Color(0xFFD85A30);
  static const Color accentStrong = Color(0xFF993C1D);
  static const Color onAccent = Color(0xFFFFF6EE);

  static const Color accentSecondary = Color(0xFF0F6E56);
  static const Color accentSecondarySoft = Color(0xFFE1F5EE);

  static const Color disabled = Color(0xFFCDBC97);
  static const Color success = Color(0xFF3B6D11);
  static const Color warning = Color(0xFFBA7517);
  static const Color danger = Color(0xFFA32D2D);
}
