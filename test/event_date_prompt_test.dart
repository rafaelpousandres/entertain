import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/event_draft.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/data/events_repository.dart';
import 'package:entertain/features/events/screens/event_form_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Release 1.0.29+43 S-02 — on the FIRST save of an event with no date, one
/// soft invitation to add one, with a clear way out: saving without a date
/// stays possible, and the invitation never appears when editing an existing
/// event (its first save already happened).
SupabaseClient _dummyClient() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Event _event() => Event(
  id: 'e1',
  groupId: 'g1',
  title: 'Festa',
  type: EventType.dinner,
  format: EventFormat.seated,
  guestCount: 8,
  createdAt: DateTime(2026, 1, 1),
);

class _FakeEvents extends EventsRepository {
  _FakeEvents() : super(_dummyClient());

  final List<EventDraft> created = [];
  final List<EventDraft> updated = [];

  @override
  Future<Event> createEvent(EventDraft draft, {required String groupId}) async {
    created.add(draft);
    return _event();
  }

  @override
  Future<Event> updateEvent(String id, EventDraft draft) async {
    updated.add(draft);
    return _event();
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<GoRouter> pumpForm(
    WidgetTester tester,
    _FakeEvents fake, {
    String? eventId,
    Event? initialEvent,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SizedBox())),
        GoRoute(
          path: '/form',
          builder: (_, _) =>
              EventFormScreen(eventId: eventId, initialEvent: initialEvent),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(fake),
        currentGroupIdProvider.overrideWith((ref) async => 'g1'),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    router.push('/form');
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.saveAction));
    await tester.pumpAndSettle();
  }

  testWidgets('first save without a date invites, and saving undated works',
      (tester) async {
    final fake = _FakeEvents();
    await pumpForm(tester, fake);

    await tester.enterText(find.byType(TextField).first, 'Sopar de prova');
    await tapSave(tester);

    // The soft invitation, not a save.
    expect(find.text(l10n.eventDatePromptTitle), findsOneWidget);
    expect(fake.created, isEmpty);

    // The clear way out: continue without a date → the event saves undated.
    await tester.tap(find.text(l10n.eventDatePromptSkip));
    await tester.pumpAndSettle();
    expect(fake.created, hasLength(1));
    expect(fake.created.single.eventDate, isNull);
  });

  testWidgets('accepting the invitation opens the picker and saves the date',
      (tester) async {
    final fake = _FakeEvents();
    await pumpForm(tester, fake);

    await tester.enterText(find.byType(TextField).first, 'Sopar de prova');
    await tapSave(tester);

    await tester.tap(find.text(l10n.eventDatePromptAdd));
    await tester.pumpAndSettle();

    // The standard date picker; confirming today saves a dated event.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(fake.created, hasLength(1));
    expect(fake.created.single.eventDate, isNotNull);
  });

  testWidgets('dismissing the invitation returns to the form unsaved',
      (tester) async {
    final fake = _FakeEvents();
    await pumpForm(tester, fake);

    await tester.enterText(find.byType(TextField).first, 'Sopar de prova');
    await tapSave(tester);

    await tester.tapAt(const Offset(5, 5)); // barrier tap
    await tester.pumpAndSettle();

    expect(find.text(l10n.eventDatePromptTitle), findsNothing);
    expect(fake.created, isEmpty);
    // Still on the form, free to decide.
    expect(find.byTooltip(l10n.saveAction), findsOneWidget);
  });

  testWidgets('editing an existing undated event never re-invites',
      (tester) async {
    final fake = _FakeEvents();
    await pumpForm(tester, fake, eventId: 'e1', initialEvent: _event());

    await tapSave(tester);

    expect(find.text(l10n.eventDatePromptTitle), findsNothing);
    expect(fake.updated, hasLength(1));
    expect(fake.created, isEmpty);
  });
}
