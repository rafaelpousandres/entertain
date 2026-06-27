import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../data/diet.dart';

/// Spec 026 Part C — compact, colour-coded TEXT pills for a dietary status
/// (the food-industry pattern: no drawn icon, just letters + colour). Shown on
/// ingredient and dish catalog rows; renders nothing for `unknown`/`none`.
///
/// Colours follow Entertain's palette:
///  * vegan      → solid dark green, white text (the strongest)
///  * vegetarian → light green, dark-green text (a lighter step)
///  * gluten-free→ solid orange, white text
class DietaryBadges extends StatelessWidget {
  const DietaryBadges({
    super.key,
    required this.diet,
    required this.glutenFree,
    this.spacing = 4,
  });

  final DietLevel diet;
  final TriState glutenFree;
  final double spacing;

  // Entertain green / orange (Spec 026 Part C colour coding).
  static const Color _veganBg = Color(0xFF1F6B52);
  static const Color _vegetarianBg = Color(0xFFCFE7DD);
  static const Color _vegetarianFg = Color(0xFF1F6B52);
  static const Color _glutenBg = Color(0xFFD6603A);

  ({Color bg, Color fg}) _style(DietBadge b) => switch (b) {
    DietBadge.vegan => (bg: _veganBg, fg: Colors.white),
    DietBadge.vegetarian => (bg: _vegetarianBg, fg: _vegetarianFg),
    DietBadge.glutenFree => (bg: _glutenBg, fg: Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final badges = dietaryBadgesFor(diet, glutenFree);
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final b in badges)
          _Pill(label: dietBadgeAbbrev(l10n, b), style: _style(b)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.style});

  final String label;
  final ({Color bg, Color fg}) style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: style.fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
          height: 1.1,
        ),
      ),
    );
  }
}
