import 'package:entertain/app.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder screen renders the localized title and body',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EntertainApp()));
    await tester.pumpAndSettle();

    // English is the fallback locale; both strings should be on screen.
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(en.placeholderTitle), findsOneWidget);
    expect(find.text(en.placeholderBody), findsOneWidget);
  });
}
