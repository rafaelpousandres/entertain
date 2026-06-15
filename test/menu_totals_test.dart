import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/menu_totals.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 012 §2.6 — the Menu totals maths: dish/serving sums, the
/// servings-per-guest ratio (one decimal, locale separator), and the guests = 0
/// edge case where the ratio must be omitted rather than dividing by zero.
EventDish _dish(DishCategory category, int servings) => EventDish(
  id: 'd-$category-$servings',
  name: 'Dish',
  category: category,
  servings: servings,
  sortOrder: 0,
);

void main() {
  group('MenuTotals.from', () {
    test('sums dishes and servings across categories', () {
      final dishes = [
        _dish(DishCategory.starter, 4),
        _dish(DishCategory.starter, 2),
        _dish(DishCategory.main, 6),
        _dish(DishCategory.dessert, 8),
      ];

      final totals = MenuTotals.from(dishes, guestCount: 8);

      expect(totals.dishCount, 4);
      expect(totals.servingsTotal, 20);
      expect(totals.servingsPerGuest, 20 / 8); // 2.5
    });

    test('guests = 0 omits the ratio (no division by zero)', () {
      final dishes = [_dish(DishCategory.main, 6)];

      final totals = MenuTotals.from(dishes, guestCount: 0);

      expect(totals.dishCount, 1);
      expect(totals.servingsTotal, 6);
      expect(totals.servingsPerGuest, isNull);
    });

    test('an empty menu is all zeros with a null ratio when guests = 0', () {
      final totals = MenuTotals.from(const [], guestCount: 0);

      expect(totals.dishCount, 0);
      expect(totals.servingsTotal, 0);
      expect(totals.servingsPerGuest, isNull);
    });

    test('a whole-number ratio is still a double (12 / 4 = 3.0)', () {
      final dishes = [_dish(DishCategory.main, 12)];

      final totals = MenuTotals.from(dishes, guestCount: 4);

      expect(totals.servingsPerGuest, 3.0);
    });
  });

  group('formatRatioOneDecimal', () {
    test('English uses a point and keeps one decimal', () {
      expect(formatRatioOneDecimal(2.5, '.'), '2.5');
      expect(formatRatioOneDecimal(3.0, '.'), '3.0'); // trailing zero kept
    });

    test('Catalan/Spanish use a comma', () {
      expect(formatRatioOneDecimal(2.5, ','), '2,5');
      expect(formatRatioOneDecimal(3.0, ','), '3,0');
    });

    test('rounds to one decimal', () {
      expect(formatRatioOneDecimal(20 / 7, '.'), '2.9'); // 2.857… → 2.9
      expect(formatRatioOneDecimal(20 / 7, ','), '2,9');
    });
  });
}
