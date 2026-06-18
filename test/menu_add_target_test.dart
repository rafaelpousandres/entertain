import 'package:entertain/features/events/data/menu_add_target.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 017 §A.1 — the single Menu add button follows the open accordion
/// section: Begudes open → add a drink; a dish category open or everything
/// collapsed → add a dish.
void main() {
  group('menuAddTargetFor', () {
    test('drinks section open → drink', () {
      expect(
        menuAddTargetFor(drinksSectionOpen: true),
        MenuAddTarget.drink,
      );
    });

    test('drinks section closed (dish category open or all collapsed) → dish', () {
      expect(
        menuAddTargetFor(drinksSectionOpen: false),
        MenuAddTarget.dish,
      );
    });
  });
}
