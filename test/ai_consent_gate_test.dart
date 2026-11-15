import 'package:entertain/features/ai_consent/data/ai_consent_prefs.dart';
import 'package:entertain/features/ai_consent/widgets/ai_consent_gate.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spec 035 §E — the AI screens stay behind an explicit, one-time consent to
/// sending the request to the third-party AI provider (App Review Guideline
/// 5.1.2(i)). Until the user accepts, the AI screen is not even built.
const _aiScreen = Scaffold(body: Text('AI SCREEN'));

Widget _app() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AiConsentGate(child: _aiScreen),
          ),
        ),
        child: const Text('OPEN'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first use: asks, names the provider, and hides the AI screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _open(tester);

    expect(find.text('AI SCREEN'), findsNothing);
    expect(find.textContaining('Anthropic'), findsOneWidget);
    expect(find.textContaining('What you type'), findsOneWidget);
    expect(find.textContaining('translate'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('I agree, continue'), findsOneWidget);
  });

  testWidgets('accepting opens the AI screen and is remembered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _open(tester);
    await tester.tap(find.text('I agree, continue'));
    await tester.pumpAndSettle();

    expect(find.text('AI SCREEN'), findsOneWidget);
    expect(await AiConsentPrefs.read(), isTrue);
  });

  testWidgets('cancelling leaves without consenting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('AI SCREEN'), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    expect(await AiConsentPrefs.read(), isFalse);
  });

  testWidgets('once consented, the AI screen opens directly', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_consent_given': true});
    await _open(tester);

    expect(find.text('AI SCREEN'), findsOneWidget);
    expect(find.textContaining('Anthropic'), findsNothing);
  });
}
