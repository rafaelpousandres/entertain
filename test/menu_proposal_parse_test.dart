import 'package:entertain/features/ai_menu_wizard/data/menu_proposal.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 022 §7 — pure parse of a proposed menu: the three item kinds (catalog
/// dish ref, catalog drink ref, new dish card), and a malformed item that is
/// skipped rather than failing the whole proposal.
void main() {
  List<dynamic> sampleItems() => [
    {
      'type': 'catalog_dish',
      'dish_id': 'dish-amanida',
      'name': 'Amanida',
      'category': 'starter',
    },
    {
      'type': 'new_dish',
      'card': {
        'name': {'ca': 'Tiramisú', 'es': 'Tiramisú', 'en': 'Tiramisu'},
        'original_locale': 'ca',
        'category': 'dessert',
        'base_servings': 8,
        'preparation': '1. Munta la nata.\n2. Munta-ho.',
        'photo': {'preview': 'https://example.test/p.jpg'},
        'ingredients': [
          {
            'existing_id': null,
            'new': {
              'name': {'ca': 'Mascarpone'},
              'original_locale': 'ca',
            },
            'quantity': 250,
            'unit_code': 'g',
            'display_name': 'Mascarpone',
            'is_new': true,
            'unit_label': 'g',
          },
        ],
      },
    },
    {'type': 'catalog_drink', 'drink_id': 'drink-vi', 'name': 'Vi negre'},
  ];

  test('parses catalog dish, new dish and catalog drink in order', () {
    final p = MenuProposal.fromItems(sampleItems(), locale: 'ca');
    expect(p.items.length, 3);

    final catalogDish = p.items[0] as CatalogDishItem;
    expect(catalogDish.dishId, 'dish-amanida');
    expect(catalogDish.name, 'Amanida');
    expect(catalogDish.category, DishCategory.starter);

    final newDish = p.items[1] as NewDishItem;
    expect(newDish.card.displayName, 'Tiramisú');
    expect(newDish.card.category, DishCategory.dessert);
    expect(newDish.card.baseServings, 8);
    expect(newDish.card.newIngredientCount, 1);
    expect(newDish.title, 'Tiramisú');

    final drink = p.items[2] as CatalogDrinkItem;
    expect(drink.drinkId, 'drink-vi');
    expect(drink.name, 'Vi negre');
  });

  test('a malformed item is skipped, not fatal to the proposal', () {
    final items = sampleItems()..insert(1, {'type': 'mystery'});
    final p = MenuProposal.fromItems(items, locale: 'ca');
    // The unknown item is dropped; the three valid ones survive.
    expect(p.items.length, 3);
    expect(p.items.whereType<CatalogDishItem>().length, 1);
    expect(p.items.whereType<NewDishItem>().length, 1);
    expect(p.items.whereType<CatalogDrinkItem>().length, 1);
  });

  test('empty proposal parses to no items', () {
    final p = MenuProposal.fromItems(const [], locale: 'ca');
    expect(p.items, isEmpty);
  });
}
