import 'package:entertain/features/catalog/data/catalog_providers.dart';
import 'package:entertain/features/catalog/data/reference_data.dart';
import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/event_dish_line.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/screens/event_dish_detail_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/ui/stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory [EventsRepository] backing the §2.1 regression test. Only the
/// methods the dish-detail screen and the menu list touch are overridden; the
/// inherited client is never used (a throwaway is passed to `super`).
class _FakeEventsRepository extends EventsRepository {
  _FakeEventsRepository(this._dish)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          // No auto-refresh ticker, so the throwaway client leaves no pending
          // timers behind when the widget tree is torn down.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  EventDish _dish;

  @override
  Future<EventDish> fetchEventDish(String eventDishId) async => _dish;

  @override
  Future<List<EventDishLine>> listEventDishLines(String eventDishId) async =>
      const <EventDishLine>[];

  @override
  Future<List<EventDish>> listEventDishes(String eventId) async => [_dish];

  @override
  Future<void> updateEventDishServings(String eventDishId, int servings) async {
    _dish = EventDish(
      id: _dish.id,
      name: _dish.name,
      category: _dish.category,
      servings: servings,
      sortOrder: _dish.sortOrder,
      sourceDishId: _dish.sourceDishId,
    );
  }
}

void main() {
  testWidgets(
    'Fixes §2.1: changing servings on the dish detail refreshes the menu card '
    'without a restart',
    (tester) async {
      const eventId = 'event-1';
      const eventDishId = 'dish-1';
      final fake = _FakeEventsRepository(
        const EventDish(
          id: eventDishId,
          name: 'Amanida',
          category: DishCategory.starter,
          servings: 4,
          sortOrder: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(fake),
            // The detail screen reads these reference catalogs; empty data keeps
            // the test off the network.
            unitsProvider('en').overrideWith((ref) => <Unit>[]),
            supplierCategoriesProvider(
              'en',
            ).overrideWith((ref) => <SupplierCategory>[]),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Column(
              children: [
                const Expanded(
                  child: EventDishDetailScreen(
                    eventId: eventId,
                    eventDishId: eventDishId,
                  ),
                ),
                // Stands in for the menu-tab dish card: both read the dish's
                // servings from `eventDishesProvider`.
                Consumer(
                  builder: (context, ref, _) {
                    final dishes = ref
                        .watch(eventDishesProvider(eventId))
                        .value;
                    final servings = dishes == null || dishes.isEmpty
                        ? '-'
                        : '${dishes.first.servings}';
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('card:$servings'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The menu card starts at the persisted servings.
      expect(find.text('card:4'), findsOneWidget);

      // Increment the servings via the detail screen's stepper.
      await tester.tap(
        find.descendant(
          of: find.byType(StepperField),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pumpAndSettle();

      // Before the fix the card stayed at 4 until a cold restart; now it
      // reflects the new value immediately.
      expect(find.text('card:5'), findsOneWidget);
      expect(find.text('card:4'), findsNothing);
    },
  );
}
