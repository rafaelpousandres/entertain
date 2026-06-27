import 'package:entertain/features/hints/data/hint.dart';
import 'package:entertain/features/hints/screens/hints_on_entry.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spec 026 A.2 — the on-entry sheet: "Més…" advances, close dismisses.
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
}
