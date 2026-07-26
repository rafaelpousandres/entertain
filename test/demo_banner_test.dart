import 'package:entertain/features/demo/data/demo_providers.dart';
import 'package:entertain/features/demo/data/demo_repository.dart';
import 'package:entertain/features/demo/widgets/demo_banner.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Release 1.0.29+43 S-04 — clearing the example data is destructive, so
/// "Start from scratch" must confirm first: Cancel·lar is the default (initial
/// focus), the destructive action is marked as such, and nothing is deleted
/// unless the destructive action is explicitly chosen.
class _FakeDemoRepository extends DemoRepository {
  _FakeDemoRepository()
      : super(
          SupabaseClient(
            'http://localhost',
            'test-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  int clearCalls = 0;

  @override
  Future<List<({String bucket, String path})>> clearDemoData() async {
    clearCalls++;
    return const [];
  }
}

Widget _app(_FakeDemoRepository fake) => ProviderScope(
      overrides: [
        demoRepositoryProvider.overrideWithValue(fake),
        hasDemoDataProvider.overrideWith((ref) async => true),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DemoBanner()),
      ),
    );

void main() {
  late AppLocalizations l10n;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> openDialog(WidgetTester tester, _FakeDemoRepository fake) async {
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.demoBannerAction));
    await tester.pumpAndSettle();
  }

  testWidgets('the action opens a confirmation dialog instead of deleting',
      (tester) async {
    final fake = _FakeDemoRepository();
    await openDialog(tester, fake);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.demoClearConfirmTitle), findsOneWidget);
    expect(fake.clearCalls, 0, reason: 'opening the dialog must not delete');

    // Cancel·lar is the default: it holds the initial focus.
    final cancel = tester.widget<TextButton>(find.ancestor(
      of: find.text(l10n.cancelAction),
      matching: find.byType(TextButton),
    ));
    expect(cancel.autofocus, isTrue);

    // The destructive action is marked as such (danger color).
    final confirmLabel = tester.widget<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.demoClearConfirmButton),
      ),
    );
    expect(confirmLabel.style?.color, AppColors.danger);
  });

  testWidgets('cancelling keeps the data', (tester) async {
    final fake = _FakeDemoRepository();
    await openDialog(tester, fake);

    await tester.tap(find.text(l10n.cancelAction));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.clearCalls, 0);
    // The banner is still there — nothing was cleared or dismissed.
    expect(find.text(l10n.demoBannerAction), findsOneWidget);
  });

  testWidgets('confirming performs the clear', (tester) async {
    final fake = _FakeDemoRepository();
    await openDialog(tester, fake);

    await tester.tap(find.text(l10n.demoClearConfirmButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.clearCalls, 1);
  });
}
