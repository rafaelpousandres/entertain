import 'package:entertain/features/catalog/data/diet.dart';
import 'package:entertain/features/catalog/data/dish.dart' show DishAcquisitionMode;
import 'package:flutter_test/flutter_test.dart';

/// Spec 025 Part B/C — dietary enums, conservative derivation, and the filter
/// predicates. All pure.
void main() {
  group('wire round-trips', () {
    test('DietLevel', () {
      for (final d in DietLevel.values) {
        expect(DietLevelWire.parse(d.wire), d);
      }
      expect(DietLevelWire.parse('garbage'), DietLevel.unknown);
      expect(DietLevelWire.parse(null), DietLevel.unknown);
    });
    test('TriState', () {
      for (final t in TriState.values) {
        expect(TriStateWire.parse(t.wire), t);
      }
      expect(TriStateWire.parse('garbage'), TriState.unknown);
    });
  });

  group('deriveDishDiet (conservative)', () {
    test('any none dominates, even amid unknowns/vegan', () {
      expect(
        deriveDishDiet([DietLevel.vegan, DietLevel.unknown, DietLevel.none]),
        DietLevel.none,
      );
    });
    test('any unknown (no none) → unknown', () {
      expect(
        deriveDishDiet([DietLevel.vegan, DietLevel.unknown]),
        DietLevel.unknown,
      );
    });
    test('all vegan → vegan', () {
      expect(
        deriveDishDiet([DietLevel.vegan, DietLevel.vegan]),
        DietLevel.vegan,
      );
    });
    test('mix of vegan + vegetarian (no none/unknown) → vegetarian', () {
      expect(
        deriveDishDiet([DietLevel.vegan, DietLevel.vegetarian]),
        DietLevel.vegetarian,
      );
    });
    test('empty → unknown', () {
      expect(deriveDishDiet([]), DietLevel.unknown);
    });
  });

  group('deriveDishGlutenFree', () {
    test('any no dominates', () {
      expect(
        deriveDishGlutenFree([TriState.yes, TriState.unknown, TriState.no]),
        TriState.no,
      );
    });
    test('any unknown (no no) → unknown', () {
      expect(
        deriveDishGlutenFree([TriState.yes, TriState.unknown]),
        TriState.unknown,
      );
    });
    test('all yes → yes', () {
      expect(deriveDishGlutenFree([TriState.yes, TriState.yes]), TriState.yes);
    });
  });

  group('effectiveDishDiet', () {
    test('has ingredients → derived (manual ignored)', () {
      expect(
        effectiveDishDiet(
          hasIngredients: true,
          manual: DietLevel.vegan,
          ingredientDiets: [DietLevel.none],
        ),
        DietLevel.none,
      );
    });
    test('no ingredients → manual', () {
      expect(
        effectiveDishDiet(
          hasIngredients: false,
          manual: DietLevel.vegetarian,
          ingredientDiets: const [],
        ),
        DietLevel.vegetarian,
      );
    });
  });

  group('dishMatchesDietary', () {
    test('vegan chip matches vegan only', () {
      expect(dishMatchesDietary(DietLevel.vegan, TriState.unknown, {DietChip.vegan}), isTrue);
      expect(dishMatchesDietary(DietLevel.vegetarian, TriState.unknown, {DietChip.vegan}), isFalse);
    });
    test('vegetarian chip matches vegetarian AND vegan', () {
      expect(dishMatchesDietary(DietLevel.vegetarian, TriState.unknown, {DietChip.vegetarian}), isTrue);
      expect(dishMatchesDietary(DietLevel.vegan, TriState.unknown, {DietChip.vegetarian}), isTrue);
      expect(dishMatchesDietary(DietLevel.none, TriState.unknown, {DietChip.vegetarian}), isFalse);
    });
    test('gluten-free chip matches yes only; unknown never matches', () {
      expect(dishMatchesDietary(DietLevel.unknown, TriState.yes, {DietChip.glutenFree}), isTrue);
      expect(dishMatchesDietary(DietLevel.unknown, TriState.unknown, {DietChip.glutenFree}), isFalse);
    });
    test('unknown diet never matches a positive chip', () {
      expect(dishMatchesDietary(DietLevel.unknown, TriState.unknown, {DietChip.vegan}), isFalse);
      expect(dishMatchesDietary(DietLevel.unknown, TriState.unknown, {DietChip.vegetarian}), isFalse);
    });
    test('AND across chips', () {
      // vegan + gluten-free: needs both.
      expect(dishMatchesDietary(DietLevel.vegan, TriState.yes, {DietChip.vegan, DietChip.glutenFree}), isTrue);
      expect(dishMatchesDietary(DietLevel.vegan, TriState.no, {DietChip.vegan, DietChip.glutenFree}), isFalse);
    });
    test('empty selection matches everything', () {
      expect(dishMatchesDietary(DietLevel.unknown, TriState.unknown, {}), isTrue);
    });
  });

  group('dishMatchesAcquisition', () {
    test('null filter matches both', () {
      expect(dishMatchesAcquisition(DishAcquisitionMode.cooked, null), isTrue);
      expect(dishMatchesAcquisition(DishAcquisitionMode.bought, null), isTrue);
    });
    test('cooked vs bought', () {
      expect(dishMatchesAcquisition(DishAcquisitionMode.cooked, DishAcquisitionMode.cooked), isTrue);
      expect(dishMatchesAcquisition(DishAcquisitionMode.bought, DishAcquisitionMode.cooked), isFalse);
    });
  });
}
