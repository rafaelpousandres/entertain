import 'package:entertain/features/ai_dish_assistant/data/dish_assistant_repository.dart';
import 'package:entertain/features/ai_dish_assistant/data/dish_card.dart';
import 'package:entertain/features/ai_menu_wizard/data/menu_proposal.dart';
import 'package:entertain/features/ai_menu_wizard/data/menu_wizard_providers.dart';
import 'package:entertain/features/ai_menu_wizard/data/menu_wizard_repository.dart';
import 'package:entertain/features/ai_menu_wizard/screens/menu_wizard_screen.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 022 §7 — client wiring with a faked Edge Function: propose shows the
/// review (catalog vs new vs drink marked); confirm adds the selected items and
/// returns to the menu; a reached limit surfaces the seam.
SupabaseClient _dummyClient() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

DishCard _newCard() => DishCard.fromJson(const {
  'name': {'ca': 'Tiramisú', 'es': 'Tiramisú', 'en': 'Tiramisu'},
  'original_locale': 'ca',
  'category': 'dessert',
  'base_servings': 8,
  'preparation': '1. Munta-ho.',
  'ingredients': [],
}, locale: 'en');

Event _fakeEvent() => Event(
  id: 'e1',
  groupId: 'g1',
  title: 'Festa',
  type: EventType.dinner,
  format: EventFormat.seated,
  guestCount: 8,
  createdAt: DateTime(2026, 1, 1),
);

MenuProposal _proposal() => MenuProposal(
  items: [
    const CatalogDishItem(
      dishId: 'cat-1',
      name: 'Amanida',
      category: DishCategory.starter,
    ),
    NewDishItem(card: _newCard()),
    const CatalogDrinkItem(drinkId: 'drink-1', name: 'Vi negre'),
  ],
);

class _FakeMenuWizard extends MenuWizardRepository {
  _FakeMenuWizard({this.throwLimit = false})
    : super(_dummyClient(), _DummyDish(), _DummyEvents());

  final bool throwLimit;
  final List<String> proposeCalls = [];
  final List<List<ProposedItem>> acceptCalls = [];

  @override
  Future<({MenuProposal proposal, QuotaStatus usage})> propose({
    required String eventId,
    required Map<String, dynamic> answers,
    required String freeText,
    required String locale,
  }) async {
    proposeCalls.add(eventId);
    if (throwLimit) throw const QuotaExceededException(used: 2, limit: 2);
    return (proposal: _proposal(), usage: const QuotaStatus(used: 1, limit: 2));
  }

  @override
  Future<({int added, int failed})> accept({
    required String eventId,
    required List<ProposedItem> items,
  }) async {
    acceptCalls.add(items);
    return (added: items.length, failed: 0);
  }

  @override
  Future<QuotaStatus> fetchQuota(String groupId) async =>
      const QuotaStatus(used: 1, limit: 2);
}

class _DummyDish extends DishAssistantRepository {
  _DummyDish() : super(_dummyClient());
}

class _DummyEvents extends EventsRepository {
  _DummyEvents() : super(_dummyClient());
}

Widget _app(GoRouter router, _FakeMenuWizard fake) => ProviderScope(
  overrides: [
    menuWizardRepositoryProvider.overrideWithValue(fake),
    menuWizardQuotaProvider.overrideWith(
      (ref) async => const QuotaStatus(used: 1, limit: 2),
    ),
    eventByIdProvider.overrideWith((ref, id) async => _fakeEvent()),
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
      path: '/wizard',
      builder: (_, _) => const MenuWizardScreen(eventId: 'e1'),
    ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  GoRouter router,
  _FakeMenuWizard fake,
) async {
  await tester.pumpWidget(_app(router, fake));
  await tester.pumpAndSettle();
  router.push('/wizard');
  await tester.pumpAndSettle();
}

Future<void> _generate(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.menuWizardGenerateAction));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('propose shows the review with catalog/new/drink marked', (
    tester,
  ) async {
    final fake = _FakeMenuWizard();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);

    await _generate(tester, l10n);

    expect(fake.proposeCalls, ['e1']);
    expect(find.text('Amanida'), findsOneWidget);
    expect(find.text('Tiramisu'), findsOneWidget);
    expect(find.text('Vi negre'), findsOneWidget);
    // The new dish is marked "new"; the two catalog refs marked "from catalog".
    expect(find.text(l10n.menuWizardNewDishMarker), findsOneWidget);
    expect(find.text(l10n.menuWizardCatalogMarker), findsNWidgets(2));
    expect(fake.acceptCalls, isEmpty); // propose never persists
  });

  testWidgets('confirm adds the selected items and returns to the menu', (
    tester,
  ) async {
    final fake = _FakeMenuWizard();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);
    await _generate(tester, l10n);

    await tester.tap(find.text(l10n.menuWizardConfirmAction(3)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(fake.acceptCalls.length, 1);
    expect(fake.acceptCalls.first.length, 3); // all three selected by default
    expect(find.text('HOME'), findsOneWidget); // popped back
  });

  testWidgets('deselecting an item drops it from the accepted set', (
    tester,
  ) async {
    final fake = _FakeMenuWizard();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);
    await _generate(tester, l10n);

    // Untick the drink, then confirm — the label updates to 2.
    await tester.tap(find.text('Vi negre'));
    await tester.pump();
    await tester.tap(find.text(l10n.menuWizardConfirmAction(2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(fake.acceptCalls.first.length, 2);
    expect(
      fake.acceptCalls.first.whereType<CatalogDrinkItem>(),
      isEmpty,
    );
  });

  testWidgets('a reached limit shows the seam and blocks (no review)', (
    tester,
  ) async {
    final fake = _FakeMenuWizard(throwLimit: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await _open(tester, router, fake);

    await _generate(tester, l10n);

    expect(fake.proposeCalls.length, 1);
    expect(find.text(l10n.menuWizardLimitReachedTitle), findsOneWidget);
    expect(find.text('Amanida'), findsNothing); // no proposal shown
  });
}
