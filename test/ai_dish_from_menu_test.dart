import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_providers.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_card.dart';
import 'package:entertain/features/ai_dish_assistant/screens/dish_assistant_screen.dart';
import 'package:entertain/features/catalog/data/catalog_providers.dart';
import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/screens/add_dish_to_menu_screen.dart';
import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 034 §A2 — a dish can be created with the AI assistant straight from the
/// event menu's add flow: it is persisted to the catalog by the same
/// generate → review → save pipeline (one `generate`, so the quota is consumed
/// exactly as from the catalog) and lands on the menu after the servings step.

SupabaseClient _client() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeAssistant extends DishAssistantRepository {
  _FakeAssistant() : super(_client());

  int generateCalls = 0;
  int saveCalls = 0;

  @override
  Future<({DishCard card, QuotaStatus usage})> generate({
    required String text,
    required String locale,
  }) async {
    generateCalls++;
    return (
      card: DishCard.fromJson(const {
        'name': {'ca': 'Carbonara', 'es': 'Carbonara', 'en': 'Carbonara'},
        'description': 'Pasta amb ou i guanciale.',
        'category': 'main',
        'base_servings': 4,
        'preparation': '1. Bull la pasta.',
        'photo': null,
        'ingredients': [],
      }, locale: 'en'),
      usage: const QuotaStatus(used: 2, limit: 3),
    );
  }

  @override
  Future<String> save({required DishCard card}) async {
    saveCalls++;
    return 'dish-ai';
  }
}

class _FakeEvents extends EventsRepository {
  _FakeEvents() : super(_client());

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

Future<({_FakeAssistant assistant, _FakeEvents events})> _openAssistantFromMenu(
  WidgetTester tester,
) async {
  final assistant = _FakeAssistant();
  final events = _FakeEvents();
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
      GoRoute(
        path: '/ai-dish-assistant',
        builder: (_, state) => DishAssistantScreen(
          returnCreatedDish: state.uri.queryParameters['return'] == 'dish',
        ),
      ),
      GoRoute(
        path: '/dishes/:id',
        builder: (_, _) => const Scaffold(body: Text('DISH EDITOR')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dishAssistantRepositoryProvider.overrideWithValue(assistant),
        dishAssistantQuotaProvider.overrideWith(
          (ref) async => const QuotaStatus(used: 1, limit: 3),
        ),
        eventsRepositoryProvider.overrideWithValue(events),
        dishesListProvider.overrideWith((ref) async => <Dish>[]),
        ingredientsListProvider.overrideWith((ref) async => []),
        dishByIdProvider('dish-ai').overrideWith(
          (ref) async => const Dish(
            id: 'dish-ai',
            groupId: 'group-1',
            name: 'Carbonara',
            category: DishCategory.main,
            baseServings: 4,
          ),
        ),
        eventDishesProvider(
          _eventId,
        ).overrideWith((ref) async => <EventDish>[]),
        eventByIdProvider(_eventId).overrideWith(
          (ref) async => Event(
            id: _eventId,
            groupId: 'group-1',
            title: 'Sopar',
            type: EventType.dinner,
            format: EventFormat.seated,
            guestCount: 8,
            createdAt: DateTime(2026),
          ),
        ),
        entityCoverPathsProvider(
          MediaEntityType.dish,
        ).overrideWith((ref) async => <String, String>{}),
        entityMediaProvider((
          type: MediaEntityType.dish,
          entityId: 'dish-ai',
        )).overrideWith((ref) async => <Media>[]),
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

  // The AI entry sits in the add flow, next to "create a new dish".
  await tester.tap(find.text('Create a dish with AI'));
  await tester.pumpAndSettle();
  return (assistant: assistant, events: events);
}

Future<void> _generate(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'carbonara');
  await tester.tap(find.text('Generate'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('creates the dish with AI and adds it to the menu without '
      'leaving the event', (tester) async {
    final fakes = await _openAssistantFromMenu(tester);
    await _generate(tester);

    // The menu flow says what saving will do.
    expect(find.text('Save and add'), findsOneWidget);
    await tester.tap(find.text('Save and add'));
    await tester.pumpAndSettle();

    // Persisted to the catalog by the assistant…
    expect(fakes.assistant.saveCalls, 1);
    // …never detouring through the catalog dish editor…
    expect(find.text('DISH EDITOR'), findsNothing);
    // …and the servings are asked before it lands (seated → 8 guests).
    expect(fakes.events.added, isEmpty);
    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.text('Add to menu'));
    await tester.pumpAndSettle();

    expect(fakes.events.added, [(dishId: 'dish-ai', servings: 8)]);
    expect(find.text('MENU'), findsOneWidget);
    // Quota parity with the catalog flow: exactly one metered generate.
    expect(fakes.assistant.generateCalls, 1);
  });

  testWidgets('discarding the generated card adds nothing to the menu', (
    tester,
  ) async {
    final fakes = await _openAssistantFromMenu(tester);
    await _generate(tester);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(fakes.assistant.saveCalls, 0);
    expect(fakes.events.added, isEmpty);
  });
}
