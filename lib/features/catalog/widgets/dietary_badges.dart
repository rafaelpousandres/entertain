import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/diet.dart';
import 'diet_pill.dart';

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
          DietPill(
            label: dietBadgeAbbrev(l10n, b),
            bg: dietBadgeStyle(b).bg,
            fg: dietBadgeStyle(b).fg,
          ),
      ],
    );
  }
}
