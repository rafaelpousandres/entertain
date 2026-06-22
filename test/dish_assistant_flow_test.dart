import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_providers.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_option.dart';
import 'package:entertain/features/ai_dish_assistant/screens/dish_assistant_screen.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 020 §8 — client wiring with a faked Edge Function: search lists options
/// without consuming quota; tapping one calls save and opens the new dish; a
/// reached limit surfaces the seam message and blocks (stays on the screen).
class _FakeDishAssistantRepository extends DishAssistantRepository {
  _FakeDishAssistantRepository({this.throwLimit = false})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool throwLimit;
  final List<String> searchCalls = [];
  final List<DishOption> saveCalls = [];

  @override
  Future<List<DishOption>> search({
    required String name,
    required String locale,
  }) async {
    searchCalls.add(name);
    return [
      DishOption.fromJson(const {
        'name': {'ca': 'Paella', 'es': 'Paella', 'en': 'Paella'},
        'original_locale': 'ca',
        'category': 'main',
        'base_servings': 4,
        'summary': 'Arròs de marisc',
        'photo': null,
        'ingredient_names': ['Arròs', 'Gambes'],
        'ingredients': [],
      }, locale: locale),
    ];
  }

  @override
  Future<({String dishId, QuotaStatus usage})> save({
    required DishOption option,
  }) async {
    saveCalls.add(option);
    if (throwLimit) throw const QuotaExceededException(used: 3, limit: 3);
    return (dishId: 'dish-1', usage: const QuotaStatus(used: 2, limit: 3));
  }
}

Widget _app(GoRouter router, _FakeDishAssistantRepository fake) => ProviderScope(
  overrides: [
    dishAssistantRepositoryProvider.overrideWithValue(fake),
    dishAssistantQuotaProvider.overrideWith(
      (ref) async => const QuotaStatus(used: 1, limit: 3),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
    GoRoute(
      path: '/assistant',
      builder: (_, _) => const DishAssistantScreen(),
    ),
    GoRoute(
      path: '/dishes/:id',
      builder: (_, state) =>
          Scaffold(body: Text('DISH ${state.pathParameters['id']}')),
    ),
  ],
);

/// The single option card's tap target inside the results list.
final Finder _optionCard = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(InkWell),
);

Future<void> _runSearch(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'paella');
  await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('search lists options and consumes no quota', (tester) async {
    final fake = _FakeDishAssistantRepository();
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();
    router.push('/assistant');
    await tester.pumpAndSettle();

    await _runSearch(tester);

    expect(fake.searchCalls, ['paella']);
    expect(find.text('Paella'), findsOneWidget);
    expect(_optionCard, findsOneWidget);
    expect(fake.saveCalls, isEmpty); // search alone never saves
  });

  testWidgets('picking an option saves it and opens the new dish', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();
    router.push('/assistant');
    await tester.pumpAndSettle();
    await _runSearch(tester);

    await tester.tap(_optionCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.saveCalls.length, 1);
    // Opened the freshly created dish.
    expect(find.text('DISH dish-1'), findsOneWidget);
  });

  testWidgets('a reached limit shows the message and blocks (stays on screen)', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository(throwLimit: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();
    router.push('/assistant');
    await tester.pumpAndSettle();
    await _runSearch(tester);

    await tester.tap(_optionCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.saveCalls.length, 1);
    expect(find.text(l10n.dishAssistantLimitReachedTitle), findsOneWidget);
    expect(find.text('DISH dish-1'), findsNothing); // did not navigate
  });
}
