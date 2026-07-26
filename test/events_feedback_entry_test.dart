import 'package:entertain/features/demo/data/demo_providers.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/screens/events_list_screen.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Release 1.0.30 §1 — the suggestions entry on Events must be reachable
/// WITHOUT opening any sheet, menu or dropdown, and independently of the
/// "show hints on open" toggle. The frozen failure: the only entry lived
/// inside the hints sheet, which that toggle (off on the director's device)
/// makes unreachable.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    // The exact scenario that failed: hints-on-entry DISABLED.
    SharedPreferences.setMockInitialValues({'hints_enabled': false});
  });

  Future<void> pumpEvents(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const EventsListScreen()),
        GoRoute(
          path: '/settings/suggestions',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('suggestions-stub'))),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventsListProvider.overrideWith((ref) async => []),
        eventReadinessProvider.overrideWith((ref) async => {}),
        entityCoverPathsProvider
            .overrideWith((ref, type) async => <String, String>{}),
        hasDemoDataProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the suggestions entry is visible on Events with the hints toggle OFF',
      (tester) async {
    await pumpEvents(tester);

    // Present and tappable directly on the screen as it opens — no sheet,
    // no menu, no dropdown in between.
    final entry = find.byTooltip(l10n.hintsFeedbackAction);
    expect(entry.hitTestable(), findsOneWidget);
  });

  testWidgets('tapping the entry opens the shared Suggeriments route',
      (tester) async {
    await pumpEvents(tester);

    await tester.tap(find.byTooltip(l10n.hintsFeedbackAction));
    await tester.pumpAndSettle();

    expect(find.text('suggestions-stub'), findsOneWidget);
  });
}
