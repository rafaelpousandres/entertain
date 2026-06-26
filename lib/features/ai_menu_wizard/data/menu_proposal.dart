/// Spec 022 §2 — the proposed menu returned by the `menu-wizard` `propose`
/// action, shown for review before accepting. The proposal is an ordered list of
/// [ProposedItem]s, each a catalog dish reference, a brand-new dish card, or a
/// catalog drink reference. The user deselects any, then confirms.
library;

import '../../ai_dish_assistant/data/dish_card.dart';
import '../../catalog/data/dish_category.dart';

/// One proposed menu item. Sealed so the review UI and the accept path switch
/// exhaustively over the three kinds.
sealed class ProposedItem {
  const ProposedItem();

  factory ProposedItem.fromJson(Map<String, dynamic> json, {required String locale}) {
    switch (json['type']) {
      case 'catalog_dish':
        return CatalogDishItem(
          dishId: json['dish_id'] as String,
          name: (json['name'] as String?)?.trim() ?? '',
          category: DishCategoryWire.parse((json['category'] as String?) ?? 'other'),
        );
      case 'catalog_drink':
        return CatalogDrinkItem(
          drinkId: json['drink_id'] as String,
          name: (json['name'] as String?)?.trim() ?? '',
        );
      case 'new_dish':
        return NewDishItem(
          card: DishCard.fromJson(
            (json['card'] as Map).cast<String, dynamic>(),
            locale: locale,
          ),
        );
      default:
        throw FormatException('Unknown proposed item type: ${json['type']}');
    }
  }

  /// The label shown in the review row.
  String get title;
}

/// A reference to an existing catalog dish (added via [addDishToEvent]).
class CatalogDishItem extends ProposedItem {
  const CatalogDishItem({
    required this.dishId,
    required this.name,
    required this.category,
  });

  final String dishId;
  final String name;
  final DishCategory category;

  @override
  String get title => name;
}

/// A brand-new dish to create first (reusing the 020 `dish-assistant` save) and
/// then add to the menu. Carries the full reviewable card.
class NewDishItem extends ProposedItem {
  const NewDishItem({required this.card});

  final DishCard card;

  @override
  String get title => card.displayName;
}

/// A reference to an existing catalog drink (added via [addDrinkToEvent]).
class CatalogDrinkItem extends ProposedItem {
  const CatalogDrinkItem({required this.drinkId, required this.name});

  final String drinkId;
  final String name;

  @override
  String get title => name;
}

/// The full proposal: the ordered items + the group's updated usage (the quota
/// was charged by `propose`).
class MenuProposal {
  const MenuProposal({required this.items});

  final List<ProposedItem> items;

  factory MenuProposal.fromItems(List<dynamic> rawItems, {required String locale}) {
    final items = <ProposedItem>[];
    for (final raw in rawItems) {
      // Be forgiving of a single malformed item rather than failing the whole
      // proposal — the server already validated/normalized, this is a guard.
      try {
        items.add(
          ProposedItem.fromJson((raw as Map).cast<String, dynamic>(), locale: locale),
        );
      } on FormatException {
        continue;
      }
    }
    return MenuProposal(items: items);
  }
}
