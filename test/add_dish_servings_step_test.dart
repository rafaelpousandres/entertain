import 'package:entertain/features/catalog/data/catalog_providers.dart';
import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/data/serving_scale.dart';
import 'package:entertain/features/events/screens/add_dish_to_menu_screen.dart';
import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/ui/stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 034 §A1 — adding a catalog dish to an event menu asks for the servings
/// BEFORE the dish lands, pre-filled with the format-dependent default.

class _FakeEventsRepository extends EventsRepository {
  _FakeEventsRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<({String dishId, int? servings})> added = [];

  @override
  Future<void> addDishToEvent({
    required String eventId,
    required String dishId,
    int? servings,
  }) async {
    added.add((dishId: dishId, servings: servings));
  }
}

const _eventId = 'event-1';
const _dish = Dish(
  id: 'dish-1',
  groupId: 'group-1',
  name: 'Truita',
  category: DishCategory.starter,
  baseServings: 4,
);

Event _event(EventFormat format) => Event(
  id: _eventId,
  groupId: 'group-1',
  title: 'Dinar',
  type: EventType.lunch,
  format: format,
  guestCount: 12,
  createdAt: DateTime(2026),
);

Future<_FakeEventsRepository> _openPicker(
  WidgetTester tester, {
  required EventFormat format,
  List<EventDish> inMenu = const [],
}) async {
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
        builder: (_, _) => const AddDishToMenuScreen(eventId: _eventId),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(fake),
        dishesListProvider.overrideWith((ref) async => [_dish]),
        eventDishesProvider(_eventId).overrideWith((ref) async => inMenu),
        eventByIdProvider(_eventId).overrideWith((ref) async => _event(format)),
        entityCoverPathsProvider(
          MediaEntityType.dish,
        ).overrideWith((ref) async => <String, String>{}),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/add');
  await tester.pumpAndSettle();

  // Open the dish's category and tap the dish.
  await tester.tap(find.text('Starters'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Truita'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('defaultEventDishServings', () {
    test('a seated event serves every guest', () {
      expect(
        defaultEventDishServings(seated: true, guestCount: 12, baseServings: 4),
        12,
      );
    });

    test('buffet / other keeps the dish base servings', () {
      expect(
        defaultEventDishServings(
          seated: false,
          guestCount: 12,
          baseServings: 4,
        ),
        4,
      );
    });

    test('never goes below one serving', () {
      expect(
        defaultEventDishServings(seated: true, guestCount: 0, baseServings: 4),
        1,
      );
    });
  });

  testWidgets('nothing is added until the servings are confirmed', (
    tester,
  ) async {
    final fake = await _openPicker(tester, format: EventFormat.seated);

    // The step is showing, pre-filled with the guest count (seated event)…
    expect(find.text('Add to menu'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // …and the dish has NOT been inserted yet.
    expect(fake.added, isEmpty);

    await tester.tap(find.text('Add to menu'));
    await tester.pumpAndSettle();

    expect(fake.added, [(dishId: 'dish-1', servings: 12)]);
    expect(find.text('MENU'), findsOneWidget);
  });

  testWidgets('the dish lands with the adjusted servings', (tester) async {
    final fake = await _openPicker(tester, format: EventFormat.buffet);

    // Buffet → the dish's own base servings.
    expect(find.text('4'), findsOneWidget);
    final plus = find.descendant(
      of: find.byType(StepperField),
      matching: find.byIcon(Icons.add),
    );
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.text('Add to menu'));
    await tester.pumpAndSettle();

    expect(fake.added, [(dishId: 'dish-1', servings: 6)]);
  });

  testWidgets('backing out of the servings step adds nothing', (tester) async {
    final fake = await _openPicker(tester, format: EventFormat.buffet);

    // Dismiss the sheet by tapping the scrim.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(fake.added, isEmpty);
    // Still on the picker, ready to choose again.
    expect(find.text('Truita'), findsOneWidget);
  });

  testWidgets('re-adding a dish warns about the second copy on the same step', (
    tester,
  ) async {
    final fake = await _openPicker(
      tester,
      format: EventFormat.buffet,
      inMenu: const [
        EventDish(
          id: 'ed-1',
          sourceDishId: 'dish-1',
          name: 'Truita',
          category: DishCategory.starter,
          servings: 4,
          sortOrder: 0,
        ),
      ],
    );

    expect(find.textContaining('is already in this menu'), findsOneWidget);
    // One step, not a dialog followed by a sheet.
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Add copy'));
    await tester.pumpAndSettle();
    expect(fake.added, [(dishId: 'dish-1', servings: 4)]);
  });
}
