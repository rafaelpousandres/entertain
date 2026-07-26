import 'package:entertain/features/hints/data/hint.dart';
import 'package:entertain/features/hints/screens/hints_on_entry.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spec 026 A.2 — the on-entry sheet: "Més…" advances, close dismisses.
/// Release 1.0.29+43 S-03 — plus a discreet door to the suggestions box.
void main() {
  const tipA = Hint(id: 'a', key: 'a', kind: HintKind.tip, text: 'Tip Alpha');
  const tipB = Hint(id: 'b', key: 'b', kind: HintKind.tip, text: 'Tip Beta');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('"Més…" advances to the other tip and close dismisses', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showHintsOnEntry(context, const [tipA, tipB], tipA),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Tip Alpha'), findsOneWidget);

    // "Més…" excludes the current tip → only Beta remains.
    await tester.tap(find.text(l10n.hintsMoreAction));
    await tester.pumpAndSettle();
    expect(find.text('Tip Beta'), findsOneWidget);
    expect(find.text('Tip Alpha'), findsNothing);

    // Close (X) dismisses the sheet.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Tip Beta'), findsNothing);
  });

  testWidgets('the feedback link closes the sheet and opens Suggeriments',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showHintsOnEntry(context, const [tipA, tipB], tipA),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        // The real app registers the real SuggestionsScreen on this same
        // path (app_router.dart); the sheet only needs the shared route.
        GoRoute(
          path: '/settings/suggestions',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('suggestions-stub'))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.hintsFeedbackAction));
    await tester.pumpAndSettle();

    // Sheet gone, suggestions destination reached.
    expect(find.text('Tip Alpha'), findsNothing);
    expect(find.text('suggestions-stub'), findsOneWidget);
  });
}
