import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/event_guest.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/screens/event_guests_view.dart';
import 'package:entertain/features/events/screens/guest_editor_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 023 §1.2/§1.4 — guest add flow (faked repo) and the grouped accordion
/// view (grand total + over-capacity + per-group subtotals).
SupabaseClient _dummyClient() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Event _event({int guestCount = 8}) => Event(
  id: 'e1',
  groupId: 'g1',
  title: 'Festa',
  type: EventType.dinner,
  format: EventFormat.seated,
  guestCount: guestCount,
  createdAt: DateTime(2026, 1, 1),
);

EventGuest _guest(String name, GuestState state) =>
    EventGuest(id: name, name: name, state: state);

class _FakeEvents extends EventsRepository {
  _FakeEvents() : super(_dummyClient());
  final List<
    ({
      String name,
      String? phone,
      String? email,
      GuestState state,
      bool dietVegetarian,
      bool dietVegan,
      bool dietGlutenFree,
    })
  >
  added = [];

  @override
  Future<void> addEventGuest(
    String eventId, {
    required String name,
    String? phone,
    String? email,
    GuestState state = GuestState.pendent,
    bool dietVegetarian = false,
    bool dietVegan = false,
    bool dietGlutenFree = false,
  }) async {
    added.add((
      name: name,
      phone: phone,
      email: email,
      state: state,
      dietVegetarian: dietVegetarian,
      dietVegan: dietVegan,
      dietGlutenFree: dietGlutenFree,
    ));
  }
}

void main() {
  testWidgets('add guest: form save calls addEventGuest and returns', (
    tester,
  ) async {
    final fake = _FakeEvents();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/editor',
          builder: (_, _) => const GuestEditorScreen(eventId: 'e1'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/editor');
    await tester.pumpAndSettle();

    // The name field is the first text field on the form.
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(fake.added.length, 1);
    expect(fake.added.first.name, 'Anna');
    // Default selector value on a new guest is 'pendent'.
    expect(fake.added.first.state, GuestState.pendent);
    expect(find.text('HOME'), findsOneWidget); // popped back
  });

  testWidgets('create respects the chosen state (confirmat, not pendent)', (
    tester,
  ) async {
    final fake = _FakeEvents();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GuestEditorScreen(eventId: 'e1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bru');
    // Pick "Confirmed" in the state selector before saving.
    await tester.tap(find.text(l10n.guestStateConfirmed));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fake.added.length, 1);
    expect(fake.added.first.name, 'Bru');
    expect(fake.added.first.state, GuestState.confirmat);
  });

  testWidgets('empty name blocks save (validation, no call)', (tester) async {
    final fake = _FakeEvents();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GuestEditorScreen(eventId: 'e1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fake.added, isEmpty);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.guestNameRequired), findsOneWidget);
  });

  testWidgets('grouped view: grand total, over-capacity, subtotals', (
    tester,
  ) async {
    final guests = [
      _guest('Anna', GuestState.confirmat),
      _guest('Bru', GuestState.confirmat),
      _guest('Cesc', GuestState.confirmat),
      _guest('Dora', GuestState.pendent),
    ];
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventGuestsProvider('e1').overrideWith((ref) async => guests),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EventGuestsView(event: _event(guestCount: 2))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Grand total = 4 guests; over-capacity (3 confirmed > 2 planned).
    expect(find.text(l10n.guestCountLabel(4)), findsOneWidget);
    expect(
      find.text(l10n.guestOverCapacityNotice(3, 2)),
      findsOneWidget,
    );

    // Expanding the Confirmed section reveals its 3 members.
    await tester.tap(find.text(l10n.guestStateConfirmed));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Cesc'), findsOneWidget);
    // Pending section stays collapsed → its guest not shown.
    expect(find.text('Dora'), findsNothing);
  });
}
