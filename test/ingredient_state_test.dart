import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the manual-transition matrix after Specification 007 Fixes §2.3 / §2.4:
///
/// - Outside the Rebost, a *free* matrix — any of the four work states
///   (to_order, ordered, received, missing) is reachable except the current
///   one; `at_home` is never offered.
/// - In the Rebost, a *binary* model — only the opposite of the current state
///   (at_home ↔ missing) is offered.

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

  group('allowedTransitions — outside the Rebost (free matrix)', () {
    const work = [
      IngredientState.toOrder,
      IngredientState.ordered,
      IngredientState.received,
      IngredientState.missing,
    ];

    test('offers the three other work states, never self, never at_home', () {
      for (final from in work) {
        final targets = allowedTransitions(from, isPantry: false);
        expect(targets, [for (final s in work) if (s != from) s],
            reason: 'free matrix from $from');
        expect(targets, isNot(contains(from)));
        expect(targets, isNot(contains(IngredientState.atHome)));
      }
    });

    test('to_order can now move directly to ordered (non-app order)', () {
      expect(
        allowedTransitions(IngredientState.toOrder, isPantry: false),
        contains(IngredientState.ordered),
      );
    });

    test('a legacy at_home line is offered all four work states', () {
      expect(
        allowedTransitions(IngredientState.atHome, isPantry: false),
        work,
      );
    });
  });

  group('allowedTransitions — Rebost (binary model)', () {
    test('at_home offers only missing', () {
      expect(
        allowedTransitions(IngredientState.atHome, isPantry: true),
        [IngredientState.missing],
      );
    });

    test('missing offers only at_home', () {
      expect(
        allowedTransitions(IngredientState.missing, isPantry: true),
        [IngredientState.atHome],
      );
    });

    test('a legacy work state is normalised back to at_home', () {
      for (final from in const [
        IngredientState.toOrder,
        IngredientState.ordered,
        IngredientState.received,
      ]) {
        expect(
          allowedTransitions(from, isPantry: true),
          [IngredientState.atHome],
          reason: 'pantry normalises $from',
        );
      }
    });
  });
}
