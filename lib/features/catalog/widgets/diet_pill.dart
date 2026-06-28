import 'package:flutter/material.dart';

import '../../../theme/app_typography.dart';
import '../data/diet.dart';

/// Spec 026 C / 030 §C palette — the single source for the dietary-pill colours
/// (bg encodes state; letter colour per badge for legibility). Greys are warm to
/// sit with the cream palette. Shared by the SHOW badges ([DietPill]) and the
/// CHOOSE chips (`DietChoicePill`) so picking "Vegà" later reads as the same
/// dark-green VGN everywhere.
const Color _veganBg = Color(0xFF1F6B52);
const Color _vegetarianBg = Color(0xFFCFE7DD);
const Color _vegetarianFg = Color(0xFF1F6B52);
const Color _glutenBg = Color(0xFFD6603A);
const Color _negativeBg = Color(0xFFE3DED4);
const Color _negativeFg = Color(0xFF6E6256);
const Color _unknownBg = Color(0xFF000000);

/// The fill/text colours for a dietary badge.
({Color bg, Color fg}) dietBadgeStyle(DietBadge b) => switch (b) {
  DietBadge.vegan => (bg: _veganBg, fg: Colors.white),
  DietBadge.vegetarian => (bg: _vegetarianBg, fg: _vegetarianFg),
  DietBadge.glutenFree => (bg: _glutenBg, fg: Colors.white),
  DietBadge.dietNegative || DietBadge.glutenNegative => (
    bg: _negativeBg,
    fg: _negativeFg,
  ),
  DietBadge.unknown => (bg: _unknownBg, fg: Colors.white),
};

/// SHOW pill — a compact, colour-coded text badge using the **abbreviation**
/// (VGN/VGT/SG/"?"), the food-industry pattern: no drawn icon, just letters +
/// colour. Read-only; used on catalog rows, the menu, the PDF, the guest list
/// and a dish's derived status. Choosing a diet is a different widget
/// (`DietChoicePill`), with a roomier format and full words.
class DietPill extends StatelessWidget {
  const DietPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
          height: 1.1,
        ),
      ),
    );
  }
}
