import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_providers.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_card.dart';
import 'package:entertain/features/ai_dish_assistant/screens/dish_assistant_screen.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 020 §8 (v4) — client wiring with a faked Edge Function: generate shows
/// the review card (new ingredients marked); Desa saves and opens the dish;
/// Descarta persists nothing; a reached limit surfaces the seam.
DishCard _sampleCard() => DishCard.fromJson(const {
  'name': {'ca': 'Carbonara', 'es': 'Carbonara', 'en': 'Carbonara'},
  'original_locale': 'ca',
  'description': 'Pasta amb ou i guanciale.',
  'category': 'main',
  'base_servings': 4,
  'preparation': '1. Bull la pasta.\n2. Serveix.',
  'photo': null,
  'ingredients': [
    {
      'existing_id': 'ing-pasta',
      'quantity': 320,
      'unit_code': 'g',
      'display_name': 'Pasta',
      'is_new': false,
      'unit_label': 'g',
    },
    {
      'existing_id': null,
      'new': {'name': {'ca': 'Guanciale'}, 'original_locale': 'es'},
      'quantity': 150,
      'unit_code': 'g',
      'display_name': 'Guanciale',
      'is_new': true,
      'unit_label': 'g',
    },
  ],
}, locale: 'ca');

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
  final List<String> generateCalls = [];
  final List<DishCard> saveCalls = [];

  @override
  Future<({DishCard card, QuotaStatus usage})> generate({
    required String text,
    required String locale,
  }) async {
    generateCalls.add(text);
    if (throwLimit) throw const QuotaExceededException(used: 3, limit: 3);
    return (card: _sampleCard(), usage: const QuotaStatus(used: 2, limit: 3));
  }

  @override
  Future<String> save({required DishCard card}) async {
    saveCalls.add(card);
    return 'dish-1';
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
    GoRoute(path: '/assistant', builder: (_, _) => const DishAssistantScreen()),
    GoRoute(
      path: '/dishes/:id',
      builder: (_, state) =>
          Scaffold(body: Text('DISH ${state.pathParameters['id']}')),
    ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  GoRouter router,
  _FakeDishAssistantRepository fake,
) async {
  await tester.pumpWidget(_app(router, fake));
  await tester.pumpAndSettle();
  router.push('/assistant');
  await tester.pumpAndSettle();
}

Future<void> _generate(WidgetTester tester, AppLocalizations l10n) async {
  await tester.enterText(find.byType(TextField), 'carbonara');
  await tester.tap(find.text(l10n.dishAssistantGenerateAction));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('generate shows the review card with new ingredients marked', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);

    await _generate(tester, l10n);

    expect(fake.generateCalls, ['carbonara']);
    expect(find.text('Carbonara'), findsOneWidget);
    expect(find.text('Guanciale'), findsOneWidget);
    // The new ingredient is visibly marked "will be created".
    expect(find.text(l10n.dishAssistantNewIngredientMarker), findsOneWidget);
    expect(find.text(l10n.dishAssistantSaveAction), findsOneWidget);
    expect(find.text(l10n.dishAssistantDiscardAction), findsOneWidget);
    expect(fake.saveCalls, isEmpty); // generate never saves
  });

  testWidgets('Desa saves the card and opens the new dish', (tester) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);
    await _generate(tester, l10n);

    await tester.tap(find.text(l10n.dishAssistantSaveAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.saveCalls.length, 1);
    expect(find.text('DISH dish-1'), findsOneWidget);
  });

  testWidgets('Descarta persists nothing and returns to the field', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);
    await _generate(tester, l10n);

    await tester.tap(find.text(l10n.dishAssistantDiscardAction));
    await tester.pumpAndSettle();

    expect(fake.saveCalls, isEmpty); // nothing saved
    // Back to the input: the generate button shows again, the card is gone.
    expect(find.text(l10n.dishAssistantGenerateAction), findsOneWidget);
    expect(find.text('Guanciale'), findsNothing);
  });

  testWidgets('a reached limit shows the message and blocks (no card)', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository(throwLimit: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);

    await _generate(tester, l10n);

    expect(fake.generateCalls.length, 1);
    expect(find.text(l10n.dishAssistantLimitReachedTitle), findsOneWidget);
    expect(find.text('Carbonara'), findsNothing); // no card produced
  });
}
