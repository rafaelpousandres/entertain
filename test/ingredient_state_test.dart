import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the manual-transition matrix of Specification 007 §3.3:
/// received from ordered/to_order; missing from any; back to to_order from
/// any; at_home ⇄ to_order only for pantry. `ordered` is never a manual
/// target, and a state is never offered as a transition to itself.

void main() {
  group('IngredientState.parse', () {
    test('round-trips every wire value', () {
      for (final s in IngredientState.values) {
        expect(IngredientState.parse(s.wire), s);
      }
    });
    test('falls back to toOrder on unknown / null', () {
      expect(IngredientState.parse('nonsense'), IngredientState.toOrder);
      expect(IngredientState.parse(null), IngredientState.toOrder);
    });
  });

  group('allowedTransitions', () {
    test('never offers the current state or ordered as a target', () {
      for (final from in IngredientState.values) {
        for (final pantry in [true, false]) {
          final targets = allowedTransitions(from, isPantry: pantry);
          expect(targets, isNot(contains(from)),
              reason: 'self-transition from $from');
          expect(targets, isNot(contains(IngredientState.ordered)),
              reason: 'ordered is set only by sending');
        }
      }
    });

    test('to_order: received + missing, plus at_home only for pantry', () {
      expect(
        allowedTransitions(IngredientState.toOrder, isPantry: false),
        [IngredientState.received, IngredientState.missing],
      );
      expect(
        allowedTransitions(IngredientState.toOrder, isPantry: true),
        [
          IngredientState.received,
          IngredientState.missing,
          IngredientState.atHome,
        ],
      );
    });

    test('ordered can go to received, missing or reset to to_order', () {
      expect(
        allowedTransitions(IngredientState.ordered, isPantry: false),
        [
          IngredientState.received,
          IngredientState.missing,
          IngredientState.toOrder,
        ],
      );
    });

    test('received can be reset or flagged missing', () {
      expect(
        allowedTransitions(IngredientState.received, isPantry: false),
        [IngredientState.toOrder, IngredientState.missing],
      );
    });

    test('missing can only be reset to to_order', () {
      expect(
        allowedTransitions(IngredientState.missing, isPantry: true),
        [IngredientState.toOrder],
      );
    });

    test('at_home toggles to to_order or flags missing', () {
      expect(
        allowedTransitions(IngredientState.atHome, isPantry: true),
        [IngredientState.toOrder, IngredientState.missing],
      );
    });
  });
}
