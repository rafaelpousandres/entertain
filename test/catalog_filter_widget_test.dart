import 'package:entertain/features/catalog/data/catalog_providers.dart';
import 'package:entertain/features/catalog/data/diet.dart';
import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/catalog/screens/dish_catalog_screen.dart';
import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 025 Part C — the dish-catalog filter narrows the accordion.
void main() {
  const amanida = Dish(
    id: 'a',
    groupId: 'g',
    name: 'Amanida',
    category: DishCategory.main,
    baseServings: 4,
  );
  const pernil = Dish(
    id: 'p',
    groupId: 'g',
    name: 'Pernil',
    category: DishCategory.main,
    acquisitionMode: DishAcquisitionMode.bought,
    baseServings: 4,
    diet: DietLevel.none,
  );

  testWidgets('acquisition filter narrows the list (Bought → only the bought dish)',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dishesListProvider.overrideWith((ref) async => [amanida, pernil]),
          // Amanida is a cooked dish whose ingredients derive to vegan.
          dishDietMapProvider.overrideWith(
            (ref) async => {
              'a': (diet: DietLevel.vegan, gf: TriState.unknown),
            },
          ),
          entityCoverPathsProvider(MediaEntityType.dish)
              .overrideWith((ref) async => const <String, String>{}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DishCatalogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Expand the Mains section so the rows show.
    await tester.tap(find.text(l10n.dishCategoryMain));
    await tester.pumpAndSettle();
    expect(find.text('Amanida'), findsOneWidget);
    expect(find.text('Pernil'), findsOneWidget);

    // Filter to Bought → only the bought dish remains.
    await tester.tap(find.text(l10n.filterBought));
    await tester.pumpAndSettle();
    expect(find.text('Pernil'), findsOneWidget);
    expect(find.text('Amanida'), findsNothing);
  });
}
