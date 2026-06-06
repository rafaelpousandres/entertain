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

/// The four "work" states an ingredient outside the Rebost moves through; the
/// free transition matrix (Fixes §2.3) lets the user pick any of them.
const List<IngredientState> _workStates = [
  IngredientState.toOrder,
  IngredientState.ordered,
  IngredientState.received,
  IngredientState.missing,
];

/// The legal manual transitions from a line's current state.
///
/// Two distinct models (Specification 007 Fixes §2.3 / §2.4):
///
/// - **Outside the Rebost** — a free matrix: any of the four work states
///   (`to_order`, `ordered`, `received`, `missing`) is reachable, so the user
///   can correct any classification error (including marking a line `ordered`
///   when the order was placed through a non-app channel). The current state is
///   excluded from its own option list.
/// - **Rebost (pantry)** — a binary model: a staple is either `at_home` or
///   `missing`, so only the opposite of the current state is offered.
///
/// The automatic transitions (add dish → `to_order`; send message → `ordered`)
/// are unchanged; the user can always override afterwards.
List<IngredientState> allowedTransitions(
  IngredientState from, {
  required bool isPantry,
}) {
  if (isPantry) {
    // Binary model: offer the opposite state. A pantry line that somehow holds
    // a work state (legacy data, before the category-change adjustment) is
    // normalised back into the pair by offering `at_home`.
    return from == IngredientState.atHome
        ? const [IngredientState.missing]
        : const [IngredientState.atHome];
  }
  // Free matrix: every work state except the current one. A non-pantry line in
  // `at_home` (legacy) is offered all four so it can re-enter the flow.
  return [
    for (final s in _workStates)
      if (s != from) s,
  ];
}
