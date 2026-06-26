import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_card.dart';
import 'package:entertain/features/ai_menu_wizard/data/menu_proposal.dart';
import 'package:entertain/features/ai_menu_wizard/data/menu_wizard_repository.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 022 §7 — "accept" composes already-tested pieces: each NEW dish is
/// created via the dish-assistant save, then every selected dish/drink is added
/// to the event menu (catalog dish/new dish → addDishToEvent, drink →
/// addDrinkToEvent). One failing item doesn't abort the rest.
SupabaseClient _dummyClient() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

DishCard _newCard(String nameCa) => DishCard.fromJson({
  'name': {'ca': nameCa},
  'original_locale': 'ca',
  'category': 'dessert',
  'base_servings': 6,
  'preparation': '1. Fes-ho.',
  'ingredients': const [],
}, locale: 'ca');

class _FakeDish extends DishAssistantRepository {
  _FakeDish() : super(_dummyClient());
  final List<DishCard> saved = [];
  int _n = 0;

  @override
  Future<String> save({required DishCard card}) async {
    saved.add(card);
    return 'new-dish-${++_n}';
  }
}

class _FakeEvents extends EventsRepository {
  _FakeEvents({this.failDishId}) : super(_dummyClient());

  /// When set, adding this dish id throws — to exercise the partial-failure path.
  final String? failDishId;
  final List<String> dishAdds = [];
  final List<String> drinkAdds = [];

  @override
  Future<void> addDishToEvent({
    required String eventId,
    required String dishId,
  }) async {
    if (dishId == failDishId) throw StateError('boom');
    dishAdds.add(dishId);
  }

  @override
  Future<String> addDrinkToEvent({
    required String eventId,
    required String drinkId,
  }) async {
    drinkAdds.add(drinkId);
    return 'event-drink-${drinkAdds.length}';
  }
}

void main() {
  test('creates new dishes then adds every selected item, routed by kind', () async {
    final dish = _FakeDish();
    final events = _FakeEvents();
    final repo = MenuWizardRepository(_dummyClient(), dish, events);

    final items = <ProposedItem>[
      const CatalogDishItem(
        dishId: 'cat-1',
        name: 'Amanida',
        category: DishCategory.starter,
      ),
      NewDishItem(card: _newCard('Tiramisú')),
      const CatalogDrinkItem(drinkId: 'drink-1', name: 'Vi negre'),
    ];

    final res = await repo.accept(eventId: 'e1', items: items);

    expect(res.added, 3);
    expect(res.failed, 0);
    // The new dish was created exactly once via the dish-assistant save.
    expect(dish.saved.length, 1);
    // Catalog dish added directly; the created new dish added by its returned id.
    expect(events.dishAdds, ['cat-1', 'new-dish-1']);
    expect(events.drinkAdds, ['drink-1']);
  });

  test('a single failing item is counted but does not abort the rest', () async {
    final dish = _FakeDish();
    final events = _FakeEvents(failDishId: 'cat-1');
    final repo = MenuWizardRepository(_dummyClient(), dish, events);

    final items = <ProposedItem>[
      const CatalogDishItem(
        dishId: 'cat-1',
        name: 'Falla',
        category: DishCategory.main,
      ),
      const CatalogDrinkItem(drinkId: 'drink-1', name: 'Aigua'),
    ];

    final res = await repo.accept(eventId: 'e1', items: items);

    expect(res.added, 1);
    expect(res.failed, 1);
    expect(events.dishAdds, isEmpty); // the dish add threw
    expect(events.drinkAdds, ['drink-1']); // the drink still went through
  });
}
