import 'package:entertain/features/account/data/account_repository.dart';
import 'package:entertain/features/account/widgets/delete_account_section.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 035 §D — in-app account deletion. Deleting is irreversible, so the
/// tests pin the guard rails: nothing is deleted without the explicit red
/// confirmation, the device only forgets the account once the server has
/// confirmed, and a failure leaves everything as it was.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.fail = false})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool fail;
  int deleteCalls = 0;
  int forgetCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (fail) throw StateError('server said no');
  }

  @override
  Future<void> forgetLocalAccount() async {
    forgetCalls++;
  }
}

Widget _app(_FakeAccountRepository fake) => ProviderScope(
  overrides: [accountRepositoryProvider.overrideWithValue(fake)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: DeleteAccountSection(),
      ),
    ),
  ),
);

void main() {
  testWidgets('the confirmation lists what is deleted and that it is final', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAccountRepository()));
    await tester.tap(find.text('Delete my account and data'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('events'), findsWidgets);
    expect(find.textContaining('catalog'), findsWidgets);
    expect(find.textContaining('suppliers'), findsWidgets);
    expect(find.textContaining('photos'), findsWidgets);
    expect(find.textContaining("can't be undone"), findsOneWidget);
    expect(find.text('Delete everything'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    final fake = _FakeAccountRepository();
    await tester.pumpWidget(_app(fake));
    await tester.tap(find.text('Delete my account and data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, 0);
    expect(fake.forgetCalls, 0);
    expect(find.text('Delete your account?'), findsNothing);
  });

  testWidgets('dismissing the dialog by tapping outside deletes nothing', (
    tester,
  ) async {
    final fake = _FakeAccountRepository();
    await tester.pumpWidget(_app(fake));
    await tester.tap(find.text('Delete my account and data'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, 0);
    expect(fake.forgetCalls, 0);
  });

  testWidgets('confirming deletes, forgets the account and says it is done', (
    tester,
  ) async {
    final fake = _FakeAccountRepository();
    await tester.pumpWidget(_app(fake));
    await tester.tap(find.text('Delete my account and data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    // Not pumpAndSettle: the progress spinner keeps animating behind the
    // confirmation until the app restarts.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fake.deleteCalls, 1);
    expect(fake.forgetCalls, 1);
    expect(
      find.text('Your account and all your data have been deleted.'),
      findsOneWidget,
    );

    // Acknowledging closes the confirmation (the restart itself needs the
    // AppRestart ancestor that only the real app has).
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Your account and all your data have been deleted.'),
      findsNothing,
    );
  });

  testWidgets('a server failure keeps the account on the device and can be '
      'retried', (tester) async {
    final fake = _FakeAccountRepository(fail: true);
    await tester.pumpWidget(_app(fake));
    await tester.tap(find.text('Delete my account and data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, 1);
    // The session and local data are only dropped after the server confirms.
    expect(fake.forgetCalls, 0);
    expect(find.textContaining("Couldn't delete your account"), findsOneWidget);
    expect(
      find.text('Your account and all your data have been deleted.'),
      findsNothing,
    );
    // The action is available again.
    expect(find.text('Delete my account and data'), findsOneWidget);
  });

  test('the client sends the confirmation token the server requires', () {
    // Must match CONFIRM_TOKEN in supabase/functions/delete-account/index.ts.
    expect(AccountRepository.confirmToken, 'DELETE_MY_ACCOUNT');
  });
}
