/// The ingredient state machine (Specification 007 §3.1).
///
/// Each `event_dish_ingredients` row carries one of these states, tracking
/// where the ingredient is in the user's shopping process. The wire values
/// match the `public.ingredient_state` Postgres enum.
library;

enum IngredientState {
  atHome('at_home'),
  toOrder('to_order'),
  ordered('ordered'),
  received('received'),
  missing('missing');

  const IngredientState(this.wire);

  /// Database enum value.
  final String wire;

  /// Parses a wire value, falling back to [toOrder] for unknown / null input
  /// so a row is never dropped on an unexpected value.
  static IngredientState parse(String? value) {
    for (final s in IngredientState.values) {
      if (s.wire == value) return s;
    }
    return IngredientState.toOrder;
  }
}

/// Sub-group render order within a supplier section and the summary header
/// order (Spec §3.4): Per demanar, Demanat, Rebut, Falta, A casa.
const List<IngredientState> kStateDisplayOrder = [
  IngredientState.toOrder,
  IngredientState.ordered,
  IngredientState.received,
  IngredientState.missing,
  IngredientState.atHome,
];

/// The legal manual transitions from a line's current state (Spec §3.3).
///
/// - `received` is reachable from `ordered` or `to_order`.
/// - `missing` is reachable from any state.
/// - `to_order` (reset) is reachable from any state.
/// - `at_home` ⇄ `to_order` only for pantry (Rebost) lines.
///
/// `ordered` is intentionally never a manual target: it is set only by the
/// message-dispatch flow (Spec §3.2). The current state is excluded from its
/// own option list.
List<IngredientState> allowedTransitions(
  IngredientState from, {
  required bool isPantry,
}) {
  switch (from) {
    case IngredientState.toOrder:
      return [
        IngredientState.received,
        IngredientState.missing,
        if (isPantry) IngredientState.atHome,
      ];
    case IngredientState.ordered:
      return const [
        IngredientState.received,
        IngredientState.missing,
        IngredientState.toOrder,
      ];
    case IngredientState.received:
      return const [
        IngredientState.toOrder,
        IngredientState.missing,
      ];
    case IngredientState.missing:
      return const [IngredientState.toOrder];
    case IngredientState.atHome:
      return const [
        IngredientState.toOrder,
        IngredientState.missing,
      ];
  }
}
