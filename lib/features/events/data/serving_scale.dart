/// Serving-based quantity scaling (Specification 008 §2.10).
///
/// The model is "immutable base + scale on display": an `event_dish_ingredients`
/// row stores a base [quantity] valid for `reference_servings`, and the
/// effective quantity for the event-dish's current `servings` is derived here at
/// read time. Nothing is written when the servings change, so a round-trip of
/// the servings count returns the exact original quantities.
///
/// Rounding (Spec §2.10): always **up**.
///   * Countable ingredients (no real unit — `count` magnitude, e.g. eggs):
///     round up to the next whole integer; you cannot buy 1.5 eggs.
///   * Measured ingredients (mass / volume / package): round up to 2 significant
///     figures (250 g @ 4 → 6 = 375 → 380; 100 g @ 4 → 6 = 150 → 150).
library;

import 'dart:math' as math;

/// The effective quantity of a line for [targetServings], scaling its [base]
/// quantity (expressed for [referenceServings]) proportionally and rounding up
/// per the unit kind. [countable] is true for `count`-magnitude units.
///
/// Defensive against bad data: a missing / non-positive [referenceServings]
/// means "no scaling reference", so the base is returned unscaled (still rounded
/// so the display stays consistent). A non-positive [targetServings] is treated
/// as 1 — the servings field enforces a positive integer in the UI, this just
/// avoids a zero/negative blowing up an old or malformed row.
double scaleServingQuantity({
  required double base,
  required int? referenceServings,
  required int targetServings,
  required bool countable,
}) {
  final ref = (referenceServings == null || referenceServings <= 0)
      ? targetServings
      : referenceServings;
  final target = targetServings <= 0 ? 1 : targetServings;
  final raw = ref <= 0 ? base : base / ref * target;
  return countable ? _ceilInteger(raw) : _ceilToTwoSigFigs(raw);
}

/// Rounds [value] up to the next whole integer (countable items).
double _ceilInteger(double value) {
  if (value <= 0) return 0;
  return value.ceilToDouble();
}

/// Rounds [value] up to 2 significant figures (measured items). Values that
/// already have <= 2 significant figures are returned unchanged.
double _ceilToTwoSigFigs(double value) {
  if (value <= 0) return 0;
  // Exponent of the most significant digit (e.g. 375 → 2, 2.5 → 0).
  final exponent = (math.log(value) / math.ln10).floor();
  // Scale so that two significant figures sit in the integer part, then ceil.
  final factor = math.pow(10, exponent - 1).toDouble();
  return (value / factor).ceil() * factor;
}
