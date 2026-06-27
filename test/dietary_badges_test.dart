import 'package:entertain/features/catalog/data/diet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 026 Part C — which badges show for a (effective) dietary status.
void main() {
  group('dietaryBadgesFor', () {
    test('vegan shows only the vegan badge (vegan ⇒ vegetarian)', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.unknown),
          [DietBadge.vegan]);
    });

    test('vegetarian shows the vegetarian badge', () {
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.unknown),
          [DietBadge.vegetarian]);
    });

    test('gluten-free adds its badge', () {
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.yes),
          [DietBadge.vegetarian, DietBadge.glutenFree]);
    });

    test('vegan + gluten-free → both', () {
      expect(dietaryBadgesFor(DietLevel.vegan, TriState.yes),
          [DietBadge.vegan, DietBadge.glutenFree]);
    });

    test('gluten-free alone (diet unknown) still shows the wheat badge', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.yes),
          [DietBadge.glutenFree]);
    });

    test('unknown / none / contains-gluten produce no badge', () {
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.unknown), isEmpty);
      expect(dietaryBadgesFor(DietLevel.none, TriState.unknown), isEmpty);
      expect(dietaryBadgesFor(DietLevel.none, TriState.no), isEmpty);
      expect(dietaryBadgesFor(DietLevel.vegetarian, TriState.no),
          [DietBadge.vegetarian]);
    });
  });
}
