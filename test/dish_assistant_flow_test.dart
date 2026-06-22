import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_providers.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_suggestion.dart';
import 'package:entertain/features/ai_dish_assistant/screens/dish_assistant_screen.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 020 §8 (v3) — client wiring with a faked Edge Function: `suggest` lists
/// title+URL suggestions without consuming quota; both input paths (a picked
/// suggestion, and a pasted URL) call `process`, which on success opens the new
/// dish; a reached limit surfaces the seam message and blocks.
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
  final List<String> suggestCalls = [];
  final List<({String url, String? name})> processCalls = [];

  @override
  Future<List<DishSuggestion>> suggest({
    required String name,
    required String locale,
  }) async {
    suggestCalls.add(name);
    return const [
      DishSuggestion(
        title: 'Caldereta de llagosta',
        url: 'https://example.test/caldereta',
      ),
    ];
  }

  @override
  Future<({String dishId, QuotaStatus usage})> process({
    required String url,
    String? name,
    required String locale,
  }) async {
    processCalls.add((url: url, name: name));
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
    GoRoute(path: '/assistant', builder: (_, _) => const DishAssistantScreen()),
    GoRoute(
      path: '/dishes/:id',
      builder: (_, state) =>
          Scaffold(body: Text('DISH ${state.pathParameters['id']}')),
    ),
  ],
);

Future<void> _openAssistant(
  WidgetTester tester,
  GoRouter router,
  _FakeDishAssistantRepository fake,
) async {
  await tester.pumpWidget(_app(router, fake));
  await tester.pumpAndSettle();
  router.push('/assistant');
  await tester.pumpAndSettle();
}

Future<void> _suggest(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'caldereta');
  await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('suggest lists title+URL and consumes no quota', (tester) async {
    final fake = _FakeDishAssistantRepository();
    final router = _router();
    await _openAssistant(tester, router, fake);

    await _suggest(tester);

    expect(fake.suggestCalls, ['caldereta']);
    expect(find.text('Caldereta de llagosta'), findsOneWidget);
    expect(find.text('https://example.test/caldereta'), findsOneWidget);
    expect(fake.processCalls, isEmpty); // suggest never charges
  });

  testWidgets('Path A — "Create this dish" processes the picked URL', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _openAssistant(tester, router, fake);
    await _suggest(tester);

    await tester.tap(find.text(l10n.dishAssistantCreateThisAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.processCalls.length, 1);
    expect(fake.processCalls.first.url, 'https://example.test/caldereta');
    expect(fake.processCalls.first.name, 'Caldereta de llagosta');
    expect(find.text('DISH dish-1'), findsOneWidget);
  });

  testWidgets('Path B — pasting a URL processes it directly (skips suggest)', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _openAssistant(tester, router, fake);

    await tester.enterText(
      find.byType(TextField).at(1),
      'https://example.test/pasted',
    );
    await tester.tap(find.text(l10n.dishAssistantCreateFromUrlAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.suggestCalls, isEmpty); // Path B skips suggest
    expect(fake.processCalls.length, 1);
    expect(fake.processCalls.first.url, 'https://example.test/pasted');
    expect(fake.processCalls.first.name, isNull);
    expect(find.text('DISH dish-1'), findsOneWidget);
  });

  testWidgets('Path B — a non-URL is rejected and never calls process', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _openAssistant(tester, router, fake);

    await tester.enterText(find.byType(TextField).at(1), 'not a url');
    await tester.tap(find.text(l10n.dishAssistantCreateFromUrlAction));
    await tester.pump();

    expect(fake.processCalls, isEmpty);
    expect(find.text(l10n.dishAssistantInvalidUrl), findsOneWidget);
  });

  testWidgets('a reached limit shows the message and blocks (stays)', (
    tester,
  ) async {
    final fake = _FakeDishAssistantRepository(throwLimit: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _openAssistant(tester, router, fake);
    await _suggest(tester);

    await tester.tap(find.text(l10n.dishAssistantCreateThisAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.processCalls.length, 1);
    expect(find.text(l10n.dishAssistantLimitReachedTitle), findsOneWidget);
    expect(find.text('DISH dish-1'), findsNothing); // did not navigate
  });
}
