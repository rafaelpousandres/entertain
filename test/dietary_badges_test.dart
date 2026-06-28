import 'package:entertain/features/catalog/data/diet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 026 Part C + Spec 030 §C — the badges for a (effective) dietary status.
/// Two axes, at most one badge each (max 2), with a single transversal "?" when
/// any axis is unknown.
void main() {
  group('dietaryBadgesFor', () {
    test('both axes unknown → a single "?"', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.unknown),
          [DietBadge.unknown]);
    });

    test('diet known + gluten unknown → diet badge then "?"', () {
      // Positive diet.
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.unknown),
          [DietBadge.vegan, DietBadge.unknown]);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.unknown),
          [DietBadge.vegetarian, DietBadge.unknown]);
      // Known-negative diet → grey VGT, then "?".
      expect(dietaryBadgesFor(DietLevel.none, TriState.unknown),
          [DietBadge.dietNegative, DietBadge.unknown]);
    });

    test('diet unknown + gluten known → "?" then gluten badge', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.yes),
          [DietBadge.unknown, DietBadge.glutenFree]);
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.no),
          [DietBadge.unknown, DietBadge.glutenNegative]);
    });

    test('both known → one coloured/grey badge per axis', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.yes),
          [DietBadge.vegan, DietBadge.glutenFree]);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.no),
          [DietBadge.vegetarian, DietBadge.glutenNegative]);
      // Known not-veg + has-gluten → both grey.
      expect(dietaryBadgesFor(DietLevel.none, TriState.no),
          [DietBadge.dietNegative, DietBadge.glutenNegative]);
    });

    test('vegan emits a single diet badge (vegan ⇒ vegetarian)', () {
      final badges = dietaryBadgesFor(DietLevel.vegan, TriState.yes);
      expect(badges, [DietBadge.vegan, DietBadge.glutenFree]);
      expect(badges, isNot(contains(DietBadge.vegetarian)));
      expect(badges.length, 2);
    });

    test('the user examples', () {
      // Known not vegetarian, gluten unknown → VGT(grey) + "?".
      expect(dietaryBadgesFor(DietLevel.none, TriState.unknown),
          [DietBadge.dietNegative, DietBadge.unknown]);
      // Known has gluten, diet unknown → "?" + SG(grey).
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.no),
          [DietBadge.unknown, DietBadge.glutenNegative]);
    });
  });
}
