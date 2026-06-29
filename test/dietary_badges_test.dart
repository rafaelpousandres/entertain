import 'package:entertain/features/catalog/data/diet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 026 Part C → 030 §C → **031 §A** — the show-side badges for an
/// (effective) dietary status. Two axes, at most one badge each (max 2). New
/// rule per axis: positive → its pill; unknown → the transversal "?"; known
/// **negative → nothing** (no grey pill). A single "?" when both axes unknown.
void main() {
  group('dietaryBadgesFor (Spec 031 §A)', () {
    test('both axes unknown → a single "?"', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.unknown),
          [DietBadge.unknown]);
    });

    test('positive diet + gluten unknown → diet badge then "?"', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.unknown),
          [DietBadge.vegan, DietBadge.unknown]);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.unknown),
          [DietBadge.vegetarian, DietBadge.unknown]);
    });

    test('diet unknown + gluten-free → "?" then SG', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.yes),
          [DietBadge.unknown, DietBadge.glutenFree]);
    });

    test('both positive → one pill per axis', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.yes),
          [DietBadge.vegan, DietBadge.glutenFree]);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.yes),
          [DietBadge.vegetarian, DietBadge.glutenFree]);
    });

    test('positive diet + known-negative gluten → diet pill only', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.no), [DietBadge.vegan]);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.no),
          [DietBadge.vegetarian]);
    });

    test('known-negative diet + gluten-free → SG only', () {
      expect(dietaryBadgesFor(DietLevel.none, TriState.yes),
          [DietBadge.glutenFree]);
    });

    test('known-negative axis renders nothing (no grey pill)', () {
      // Negative diet + unknown gluten → just the "?" for the unknown axis.
      expect(dietaryBadgesFor(DietLevel.none, TriState.unknown),
          [DietBadge.unknown]);
      // Unknown diet + negative gluten → just the "?".
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.no),
          [DietBadge.unknown]);
    });

    test('both axes known-negative → no pills at all', () {
      expect(dietaryBadgesFor(DietLevel.none, TriState.no), isEmpty);
    });

    test('vegan emits a single diet badge (vegan ⇒ vegetarian)', () {
      final badges = dietaryBadgesFor(DietLevel.vegan, TriState.yes);
      expect(badges, [DietBadge.vegan, DietBadge.glutenFree]);
      expect(badges, isNot(contains(DietBadge.vegetarian)));
      expect(badges.length, 2);
    });

    test('no grey negative badges are ever emitted', () {
      for (final d in DietLevel.values) {
        for (final g in TriState.values) {
          final badges = dietaryBadgesFor(d, g);
          expect(badges, isNot(contains(DietBadge.dietNegative)));
          expect(badges, isNot(contains(DietBadge.glutenNegative)));
        }
      }
    });
  });
}
