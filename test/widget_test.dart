import 'package:entertain/app.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'app shows the startup error state when no backend credentials are configured',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: EntertainApp()));
      await tester.pumpAndSettle();

      // The widget tests run without compile-time Supabase credentials, so
      // the bootstrap provider throws `StartupErrorKind.notConfigured` and
      // the gate falls through to the error screen.
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(en.startupErrorTitle), findsOneWidget);
      expect(find.text(en.retryAction), findsOneWidget);
    },
  );
}
