import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/shopping/screens/settings_screen.dart'
    show appVersionProvider;
import 'package:entertain/features/suggestions/data/suggestions_providers.dart';
import 'package:entertain/features/suggestions/data/suggestions_repository.dart';
import 'package:entertain/features/suggestions/screens/suggestions_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 021 Part A — the suggestions box: sending inserts a row (with the
/// captured app version) and the group counter reflects it. The repository is
/// faked; the real providers wire the screen, count, and invalidation.
class _FakeSuggestionsRepository extends SuggestionsRepository {
  _FakeSuggestionsRepository()
      : super(
          SupabaseClient(
            'http://localhost',
            'test-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Map<String, Object?>> inserted = [];

  @override
  Future<void> create({
    required String groupId,
    required String? userId,
    required String? appVersion,
    required String text,
  }) async {
    inserted.add({
      'group_id': groupId,
      'user_id': userId,
      'app_version': appVersion,
      'text': text,
    });
  }

  @override
  Future<int> countForGroup(String groupId) async => inserted.length;
}

Widget _app(_FakeSuggestionsRepository fake) => ProviderScope(
      overrides: [
        suggestionsRepositoryProvider.overrideWithValue(fake),
        currentUserIdProvider.overrideWithValue('user-1'),
        currentGroupIdProvider.overrideWith((ref) async => 'group-1'),
        appVersionProvider.overrideWith((ref) async => '1.0.16+17'),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SuggestionsScreen(),
      ),
    );

void main() {
  testWidgets('sending a suggestion inserts it and bumps the counter',
      (tester) async {
    final fake = _FakeSuggestionsRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    // Counter starts at zero.
    expect(find.text(l10n.suggestionsSentCount(0)), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Add a dark mode');
    await tester.pump();
    await tester.tap(find.text(l10n.suggestionsSendAction));
    await tester.pumpAndSettle();

    // Row inserted with the text and the captured app version.
    expect(fake.inserted.length, 1);
    expect(fake.inserted.first['text'], 'Add a dark mode');
    expect(fake.inserted.first['app_version'], '1.0.16+17');
    expect(fake.inserted.first['group_id'], 'group-1');

    // Field cleared, confirmation shown, counter bumped to one.
    expect(find.text(l10n.suggestionsSentConfirm), findsOneWidget);
    expect(find.text(l10n.suggestionsSentCount(1)), findsOneWidget);
  });

  testWidgets('the send button is disabled for empty/whitespace input',
      (tester) async {
    final fake = _FakeSuggestionsRepository();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    // Whitespace only — tap does nothing.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text(l10n.suggestionsSendAction));
    await tester.pumpAndSettle();

    expect(fake.inserted, isEmpty);
  });
}
