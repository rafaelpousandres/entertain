import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the manual-transition matrix after Specification 007 Fixes §2.3 / §2.4
/// and Specification 009 §2.4:
///
/// - Outside the Rebost, a *free* matrix — any of the four work states
///   (to_order, ordered, received, missing) is reachable except the current
///   one, plus `at_home` (Spec 009 §2.4: "I already have it at home", available
///   from any category).
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

    test('offers the three other work states plus at_home, never self', () {
      for (final from in work) {
        final targets = allowedTransitions(from, isPantry: false);
        // Spec 009 §2.4: the three other work states, then at_home.
        expect(targets, [...work.where((s) => s != from), IngredientState.atHome],
            reason: 'free matrix from $from');
        expect(targets, isNot(contains(from)));
        expect(targets, contains(IngredientState.atHome));
      }
    });

    test('to_order can now move directly to ordered (non-app order)', () {
      expect(
        allowedTransitions(IngredientState.toOrder, isPantry: false),
        contains(IngredientState.ordered),
      );
    });

    test('a legacy at_home line is offered the four work states, not itself', () {
      expect(
        allowedTransitions(IngredientState.atHome, isPantry: false),
        work,
      );
    });
  });

  group('DisplayState.of (Fixes round 2 §2.2)', () {
    test('an overdue ordered line maps to the delayed overlay', () {
      expect(
        DisplayState.of(IngredientState.ordered, delayed: true),
        DisplayState.delayed,
      );
    });

    test('an on-time ordered line stays ordered', () {
      expect(
        DisplayState.of(IngredientState.ordered, delayed: false),
        DisplayState.ordered,
      );
    });

    test('the delayed overlay only applies to ordered lines', () {
      for (final s in const [
        IngredientState.toOrder,
        IngredientState.received,
        IngredientState.missing,
        IngredientState.atHome,
      ]) {
        // Even if the flag is somehow set, a non-ordered line never reads as
        // delayed — only `ordered` carries the overlay.
        expect(
          DisplayState.of(s, delayed: true),
          isNot(DisplayState.delayed),
          reason: '$s',
        );
      }
    });

    test('every real state maps to its same-named display state', () {
      expect(DisplayState.of(IngredientState.toOrder, delayed: false),
          DisplayState.toOrder);
      expect(DisplayState.of(IngredientState.received, delayed: false),
          DisplayState.received);
      expect(DisplayState.of(IngredientState.missing, delayed: false),
          DisplayState.missing);
      expect(DisplayState.of(IngredientState.atHome, delayed: false),
          DisplayState.atHome);
    });
  });

  group('kDisplayStateOrder (Fixes round 3 §2.1)', () {
    test('is the concern-decreasing canonical order', () {
      expect(kDisplayStateOrder, const [
        DisplayState.toOrder, // Per demanar (red)
        DisplayState.missing, // Falta (red)
        DisplayState.delayed, // Retrassat (orange)
        DisplayState.ordered, // Demanat (yellow)
        DisplayState.received, // Rebut (green)
        DisplayState.atHome, // A casa (green)
      ]);
    });

    test('covers every display state exactly once', () {
      expect(kDisplayStateOrder.toSet(), DisplayState.values.toSet());
      expect(kDisplayStateOrder.length, DisplayState.values.length);
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
