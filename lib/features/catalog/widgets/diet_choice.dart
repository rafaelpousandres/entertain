import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/diet.dart';
import 'diet_pill.dart';

/// CHOOSE pill (Spec 029 refinement) — the input counterpart of the read-only
/// [DietPill]. A roomier rounded chip with the **full word** and a clear
/// selected/unselected look: selected fills with the state's badge colour (so it
/// matches the SHOW badge later), unselected is an outlined, muted chip. Used by
/// the guest editor (binary toggles) and the ingredient/dish editors
/// (single-select groups). The selection logic lives in the caller; this is just
/// the pressable atom.
class DietChoicePill extends StatelessWidget {
  const DietChoicePill({
    super.key,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// The badge whose palette tints the selected chip.
  final DietBadge badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = dietBadgeStyle(badge);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? style.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? style.bg : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: style.fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.button.copyWith(
                color: selected ? style.fg : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-select group of choose-pills for the diet axis (unknown / none /
/// vegetarian / vegan) — for the ingredient and dish-manual editors, where the
/// axis is multi-state (unlike the binary guest toggles). Exactly one chip is
/// selected at a time.
class DietLevelChoice extends StatelessWidget {
  const DietLevelChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DietLevel value;
  final ValueChanged<DietLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in dietLevelOrder)
          DietChoicePill(
            label: dietLevelLabel(l10n, d),
            badge: dietLevelBadge(d),
            selected: value == d,
            onTap: () => onChanged(d),
          ),
      ],
    );
  }
}

/// Single-select group of choose-pills for the gluten axis (unknown /
/// gluten-free / contains gluten). Same pattern as [DietLevelChoice].
class GlutenStateChoice extends StatelessWidget {
  const GlutenStateChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TriState value;
  final ValueChanged<TriState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in triStateOrder)
          DietChoicePill(
            label: glutenFreeLabel(l10n, g),
            badge: glutenStateBadge(g),
            selected: value == g,
            onTap: () => onChanged(g),
          ),
      ],
    );
  }
}
