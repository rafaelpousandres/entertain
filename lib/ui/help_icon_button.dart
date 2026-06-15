import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Small info icon shown next to a primary screen's title (Spec 012 §2.4).
///
/// Tapping it opens a short, translated help pop-up. A single reusable widget
/// so the pattern stays consistent across every screen; the [title] and [body]
/// come from ARB keys per screen.
class HelpIconButton extends StatelessWidget {
  const HelpIconButton({super.key, required this.title, required this.body});

  /// Pop-up heading — usually the screen or tab title.
  final String title;

  /// Short help text for the screen (2–4 telegraphic lines).
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.info_outline),
      color: AppColors.accentSecondary,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      tooltip: title,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(title, style: AppTypography.sectionTitle),
          content: Text(
            body,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.helpCloseAction,
                style: AppTypography.button.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
