import 'package:entertain/features/catalog/data/catalog_providers.dart';
import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/catalog/data/drink.dart';
import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/event_drink.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/screens/add_dish_to_menu_screen.dart';
import 'package:entertain/features/events/screens/add_drink_to_menu_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 018 §3.1 / AC2-AC3: pins the create-and-add wiring. When the editor
/// opened from the add flow returns a freshly created item, the add screen must
/// route it through the same `addDishToEvent` / `addDrinkToEvent` call used for
/// an existing item (so it lands in the event with defaults) and then return to
/// the Menu.

/// Records the add-to-event calls; everything else is unused (a throwaway
/// client satisfies `super`, mirroring the other repository fakes in this
/// suite).
class _FakeEventsRepository extends EventsRepository {
  _FakeEventsRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<({String eventId, String dishId})> addedDishes = [];
  final List<({String eventId, String drinkId})> addedDrinks = [];

  @override
  Future<void> addDishToEvent({
    required String eventId,
    required String dishId,
  }) async {
    addedDishes.add((eventId: eventId, dishId: dishId));
  }

  @override
  Future<String> addDrinkToEvent({
    required String eventId,
    required String drinkId,
  }) async {
    addedDrinks.add((eventId: eventId, drinkId: drinkId));
    return 'event-drink-1';
  }

  @override
  Future<EventDrink> fetchEventDrink(String eventDrinkId) async => EventDrink(
    id: eventDrinkId,
    name: 'Aigua',
    quantity: 1,
    sortOrder: 0,
  );
}

/// Stand-in for the editor route: pops back to the caller with [result] (the
/// created item) as soon as it is shown, the way the real editor pops with the
/// created dish/drink on save.
class _PopWith<T> extends StatefulWidget {
  const _PopWith(this.result);

  final T result;

  @override
  State<_PopWith<T>> createState() => _PopWithState<T>();
}

class _PopWithState<T> extends State<_PopWith<T>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _app(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);

void main() {
  testWidgets(
    'Spec 018 §3.1: creating a dish from the add flow adds it to the event and '
    'returns to the Menu',
    (tester) async {
      const eventId = 'event-1';
      const created = Dish(
        id: 'dish-new',
        groupId: 'group-1',
        name: 'Truita',
        category: DishCategory.starter,
        baseServings: 4,
      );
      final fake = _FakeEventsRepository();

      final router = GoRouter(
        initialLocation: '/menu',
        routes: [
          GoRoute(
            path: '/menu',
            builder: (_, _) => const Scaffold(body: Text('MENU')),
          ),
          GoRoute(
            path: '/add',
            builder: (_, _) => const AddDishToMenuScreen(eventId: eventId),
          ),
          GoRoute(
            path: '/dishes/new',
            builder: (_, _) => const _PopWith<Dish>(created),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(fake),
            dishesListProvider.overrideWith((ref) async => <Dish>[]),
            eventDishesProvider(
              eventId,
            ).overrideWith((ref) async => <EventDish>[]),
          ],
          child: _app(router),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/add');
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.addScreenCreateDishAction));
      await tester.pumpAndSettle();

      // The created dish was added to the event (defaults applied by the repo).
      expect(fake.addedDishes, [(eventId: eventId, dishId: 'dish-new')]);
      // …and we are back on the Menu.
      expect(find.text('MENU'), findsOneWidget);
    },
  );

  testWidgets(
    'Spec 025 D3: creating a drink from the add flow adds it to the event and '
    'lands on the per-event quantity editor (parity with dishes)',
    (tester) async {
      const eventId = 'event-1';
      const created = Drink(
        id: 'drink-new',
        groupId: 'group-1',
        name: 'Aigua',
      );
      final fake = _FakeEventsRepository();

      final router = GoRouter(
        initialLocation: '/menu',
        routes: [
          GoRoute(
            path: '/menu',
            builder: (_, _) => const Scaffold(body: Text('MENU')),
          ),
          GoRoute(
            path: '/add',
            builder: (_, _) => const AddDrinkToMenuScreen(eventId: eventId),
          ),
          GoRoute(
            path: '/drinks/new',
            builder: (_, _) => const _PopWith<Drink>(created),
          ),
          // Spec 025 D3: adding routes through the quantity editor (stubbed).
          GoRoute(
            path: '/events/:id/drinks/:edid/edit',
            builder: (_, _) => const Scaffold(body: Text('QTY')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(fake),
            drinksListProvider.overrideWith((ref) async => <Drink>[]),
            eventDrinksProvider(
              eventId,
            ).overrideWith((ref) async => <EventDrink>[]),
          ],
          child: _app(router),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/add');
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.addScreenCreateDrinkAction));
      await tester.pumpAndSettle();

      expect(fake.addedDrinks, [(eventId: eventId, drinkId: 'drink-new')]);
      // D3: lands on the quantity editor (not straight back to the Menu).
      expect(find.text('QTY'), findsOneWidget);
    },
  );
}
