import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../data/diet.dart';

/// Spec 026 Part C, extended in Spec 030 §C — compact, colour-coded TEXT pills
/// for a dietary status (the food-industry pattern: no drawn icon, just letters
/// + colour). Shown on ingredient and dish catalog rows, the menu and the PDF.
/// Now expresses all three states per axis so what's unclassified is visible.
///
/// Colours follow Entertain's palette (bg encodes state; letter colour per badge
/// for legibility):
///  * vegan       → solid dark green, white text (the strongest)
///  * vegetarian  → light green, dark-green text (a lighter step)
///  * gluten-free → solid orange, white text
///  * negative (not-veg / has-gluten) → light grey, darker-grey text (soft)
///  * unknown "?" → solid black, white text (stands out: what's left to classify)
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

  // Entertain green / orange (Spec 026 Part C) + grey negative & black "?"
  // (Spec 030 §C). Greys are warm to sit with the cream palette.
  static const Color _veganBg = Color(0xFF1F6B52);
  static const Color _vegetarianBg = Color(0xFFCFE7DD);
  static const Color _vegetarianFg = Color(0xFF1F6B52);
  static const Color _glutenBg = Color(0xFFD6603A);
  static const Color _negativeBg = Color(0xFFE3DED4);
  static const Color _negativeFg = Color(0xFF6E6256);
  static const Color _unknownBg = Color(0xFF000000);

  ({Color bg, Color fg}) _style(DietBadge b) => switch (b) {
    DietBadge.vegan => (bg: _veganBg, fg: Colors.white),
    DietBadge.vegetarian => (bg: _vegetarianBg, fg: _vegetarianFg),
    DietBadge.glutenFree => (bg: _glutenBg, fg: Colors.white),
    DietBadge.dietNegative || DietBadge.glutenNegative => (
      bg: _negativeBg,
      fg: _negativeFg,
    ),
    DietBadge.unknown => (bg: _unknownBg, fg: Colors.white),
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
