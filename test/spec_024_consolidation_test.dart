import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/l10n/app_localizations_ca.dart';
import 'package:entertain/l10n/app_localizations_es.dart';
import 'package:entertain/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 024 — beverage consolidation + the "Passats" group label.
void main() {
  group('Spec 024 §B — dish_category drink deprecation', () {
    test('dishCategoryActive excludes drink (the offered set)', () {
      expect(dishCategoryActive.contains(DishCategory.drink), isFalse);
      expect(dishCategoryActive, [
        DishCategory.aperitif,
        DishCategory.starter,
        DishCategory.main,
        DishCategory.dessert,
        DishCategory.other,
      ]);
    });

    test('dishCategoryOrder keeps drink as an inert vestige', () {
      // The enum value stays for historical event_dishes; only the active list
      // drops it. dishCategoryActive == order minus drink.
      expect(dishCategoryOrder.contains(DishCategory.drink), isTrue);
      expect(
        dishCategoryOrder.where((c) => c != DishCategory.drink).toList(),
        dishCategoryActive,
      );
    });

    test('historical "drink" snapshots still parse (compat preserved)', () {
      expect(DishCategoryWire.parse('drink'), DishCategory.drink);
      expect(DishCategory.drink.wire, 'drink');
    });
  });

  group('Spec 024 §A1 — past-events group label is plural', () {
    test('group header is plural, per-event badge stays singular (ca)', () {
      final ca = AppLocalizationsCa();
      expect(ca.eventStatusPastGroup, 'Passats');
      expect(ca.eventStatusPast, 'Passat');
    });

    test('es: group plural, badge singular', () {
      final es = AppLocalizationsEs();
      expect(es.eventStatusPastGroup, 'Pasados');
      expect(es.eventStatusPast, 'Pasado');
    });

    test('en: both "Past"', () {
      final en = AppLocalizationsEn();
      expect(en.eventStatusPastGroup, 'Past');
      expect(en.eventStatusPast, 'Past');
    });
  });
}
