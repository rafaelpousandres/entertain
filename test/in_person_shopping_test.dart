import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 028 §B — the in-person checklist maps onto the existing state machine.
void main() {
  group('isCheckedShoppingState', () {
    test('received / at-home read as checked', () {
      expect(isCheckedShoppingState(IngredientState.received), isTrue);
      expect(isCheckedShoppingState(IngredientState.atHome), isTrue);
    });

    test('every other state reads as unchecked', () {
      expect(isCheckedShoppingState(IngredientState.toOrder), isFalse);
      expect(isCheckedShoppingState(IngredientState.ordered), isFalse);
      expect(isCheckedShoppingState(IngredientState.missing), isFalse);
    });
  });

  group('toggledShoppingState', () {
    test('non-pantry: check → received, uncheck → to-order', () {
      // Unchecked → check sets received.
      expect(toggledShoppingState(IngredientState.toOrder, isPantry: false),
          IngredientState.received);
      expect(toggledShoppingState(IngredientState.ordered, isPantry: false),
          IngredientState.received);
      // Checked → uncheck sets to-order.
      expect(toggledShoppingState(IngredientState.received, isPantry: false),
          IngredientState.toOrder);
    });

    test('pantry: binary at-home ↔ missing', () {
      expect(toggledShoppingState(IngredientState.missing, isPantry: true),
          IngredientState.atHome);
      expect(toggledShoppingState(IngredientState.atHome, isPantry: true),
          IngredientState.missing);
    });

    test('round-trips back to an unchecked state', () {
      final checked = toggledShoppingState(IngredientState.toOrder, isPantry: false);
      expect(isCheckedShoppingState(checked), isTrue);
      final back = toggledShoppingState(checked, isPantry: false);
      expect(isCheckedShoppingState(back), isFalse);
      expect(back, IngredientState.toOrder);
    });
  });
}
