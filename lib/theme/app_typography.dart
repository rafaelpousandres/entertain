import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens from the design system.
///
/// Two families: Fraunces (serif, display) and Nunito Sans (sans, body).
/// Two weights only: regular (400) and medium (500). Sentence case always.
class AppTypography {
  AppTypography._();

  static const String _serif = 'Fraunces';
  static const String _sans = 'NunitoSans';

  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.onAccent,
  );

  /// Maps the design system scale onto a Material 3 [TextTheme] so default
  /// widgets pick up the right family and size without per-widget overrides.
  static TextTheme get textTheme => const TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: sectionTitle,
    headlineMedium: sectionTitle,
    headlineSmall: sectionTitle,
    titleLarge: sectionTitle,
    titleMedium: label,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: label,
    labelSmall: caption,
  );
}
