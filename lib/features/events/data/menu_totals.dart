/// Serving-total maths for the event Menu tab (Spec 012 §2.6).
///
/// Kept as a pure, widget-free helper so the totals — and the guests = 0 and
/// locale-decimal edge cases the spec calls out — can be unit-tested without
/// pumping a widget tree.
library;

import 'event_dish.dart';

/// Aggregate dish/serving figures for a menu.
class MenuTotals {
  const MenuTotals({
    required this.dishCount,
    required this.servingsTotal,
    required this.servingsPerGuest,
  });

  /// Total number of dishes across every category.
  final int dishCount;

  /// Sum of every dish's `servings` across every category.
  final int servingsTotal;

  /// Servings ÷ guest count, or null when the guest count is zero (the spec
  /// omits the ratio rather than dividing by zero).
  final double? servingsPerGuest;

  /// Compute the totals for [dishes] given the event's [guestCount].
  factory MenuTotals.from(List<EventDish> dishes, {required int guestCount}) {
    final servings = dishes.fold<int>(0, (sum, d) => sum + d.servings);
    return MenuTotals(
      dishCount: dishes.length,
      servingsTotal: servings,
      servingsPerGuest: guestCount <= 0 ? null : servings / guestCount,
    );
  }
}

/// Formats a ratio to exactly one decimal with the locale's radix mark
/// (comma for ca/es, point for en — resolve with `quantityDecimalSeparator`).
///
/// Unlike `formatQuantity`, this keeps the trailing decimal ("2.0" stays
/// "2,0"), because the spec specifies a fixed one-decimal ratio.
String formatRatioOneDecimal(double value, String decimalSeparator) {
  final text = value.toStringAsFixed(1);
  return decimalSeparator == '.'
      ? text
      : text.replaceFirst('.', decimalSeparator);
}
