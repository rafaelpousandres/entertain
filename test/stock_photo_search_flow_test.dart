import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:entertain/features/stock_photos/data/stock_photo.dart';
import 'package:entertain/features/stock_photos/data/stock_photo_providers.dart';
import 'package:entertain/features/stock_photos/data/stock_photo_repository.dart';
import 'package:entertain/features/stock_photos/screens/stock_photo_search_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 019 §D.2 — client wiring with a faked Edge Function: a search lists
/// results without consuming quota; tapping a result calls `save`; a success
/// returns to the editor; a reached limit surfaces the message and blocks.
class _FakeStockPhotoRepository extends StockPhotoRepository {
  _FakeStockPhotoRepository({this.throwLimit = false})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool throwLimit;
  final List<String> searchCalls = [];
  final List<StockPhoto> saveCalls = [];

  @override
  Future<List<StockPhoto>> search({
    required String query,
    required String locale,
    int page = 1,
  }) async {
    searchCalls.add(query);
    return const [
      StockPhoto(
        id: '1',
        photographer: 'Alice',
        photographerUrl: '',
        pageUrl: 'https://www.pexels.com/photo/1/',
        alt: 'paella',
        previewUrl: 'https://example.test/preview.jpg',
        fullUrl: 'https://example.test/full.jpg',
      ),
    ];
  }

  @override
  Future<QuotaStatus> save({
    required StockPhoto photo,
    required MediaEntityType type,
    required String entityId,
  }) async {
    saveCalls.add(photo);
    if (throwLimit) throw const QuotaExceededException(used: 10, limit: 10);
    return const QuotaStatus(used: 3, limit: 10);
  }
}

Widget _app(GoRouter router, _FakeStockPhotoRepository fake) => ProviderScope(
  overrides: [
    stockPhotoRepositoryProvider.overrideWithValue(fake),
    stockPhotoQuotaProvider.overrideWith(
      (ref) async => const QuotaStatus(used: 2, limit: 10),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => const Scaffold(body: Text('HOME')),
    ),
    GoRoute(
      path: '/search',
      builder: (_, _) => const StockPhotoSearchScreen(
        args: StockPhotoSearchArgs(
          type: MediaEntityType.dish,
          entityId: 'dish-1',
          locale: 'en-US',
        ),
      ),
    ),
  ],
);

/// The result tile's tap target: the single InkWell inside the results grid
/// (the search field has its own InkWells, so we scope to the GridView).
final Finder _resultTile = find.descendant(
  of: find.byType(GridView),
  matching: find.byType(InkWell),
);

Future<void> _runSearch(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'paella');
  await tester.tap(find.byIcon(Icons.search));
  // Discrete pumps (not pumpAndSettle): the result tiles hold network images
  // whose placeholder spinner would never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('search lists results and consumes no quota', (tester) async {
    final fake = _FakeStockPhotoRepository();
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();

    router.push('/search');
    await tester.pumpAndSettle();

    await _runSearch(tester);

    expect(fake.searchCalls, ['paella']);
    expect(find.text('Photo by Alice'), findsOneWidget);
    // The tile's tap target (the whole InkWell) is on-screen even though the
    // credit caption at its bottom edge sits below the 600px test viewport.
    expect(_resultTile, findsOneWidget);
    // Search alone never calls save.
    expect(fake.saveCalls, isEmpty);
  });

  testWidgets('tapping a result saves it and returns to the editor', (
    tester,
  ) async {
    final fake = _FakeStockPhotoRepository();
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();
    router.push('/search');
    await tester.pumpAndSettle();
    await _runSearch(tester);

    await tester.tap(_resultTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.saveCalls.length, 1);
    expect(fake.saveCalls.first.id, '1');
    // Popped back to the editor (home stand-in).
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a reached limit shows the message and blocks (stays on screen)', (
    tester,
  ) async {
    final fake = _FakeStockPhotoRepository(throwLimit: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = _router();
    await tester.pumpWidget(_app(router, fake));
    await tester.pumpAndSettle();
    router.push('/search');
    await tester.pumpAndSettle();
    await _runSearch(tester);

    await tester.tap(_resultTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The attempt happened, the limit-reached dialog is up, and we did NOT pop.
    expect(fake.saveCalls.length, 1);
    expect(find.text(l10n.stockLimitReachedTitle), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });
}
