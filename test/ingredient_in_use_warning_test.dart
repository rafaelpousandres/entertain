import 'package:entertain/features/catalog/data/catalog_repository.dart';
import 'package:entertain/features/catalog/widgets/delete_ingredient_dialog.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 034 §B1 — the in-use warning shown when deleting a catalog ingredient.

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// Opens the dialog/sheet under test from a button, the way a screen would.
class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final Future<void> Function(BuildContext) open;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => open(context), child: const Text('OPEN'));
}

void main() {
  group('B1 usedInDishNames', () {
    test('dedupes a dish listed on several lines, localizes and sorts', () {
      final names = usedInDishNames(
        [
          {
            'dishes': {'id': 'd2', 'name': 'Truita', 'deleted_at': null},
          },
          {
            'dishes': {'id': 'd1', 'name': 'Arròs', 'deleted_at': null},
          },
          {
            'dishes': {'id': 'd2', 'name': 'Truita', 'deleted_at': null},
          },
        ],
        {'d1': 'Rice'},
      );
      expect(names, ['Rice', 'Truita']);
    });

    test('ignores deleted dishes', () {
      final names = usedInDishNames([
        {
          'dishes': {
            'id': 'd1',
            'name': 'Arròs',
            'deleted_at': '2026-11-01T00:00:00Z',
          },
        },
      ], const {});
      expect(names, isEmpty);
    });
  });

  group('B1 delete dialog', () {
    testWidgets('names the dishes that use the ingredient', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          _Opener((context) async {
            result = await showDeleteIngredientDialog(
              context,
              usedIn: const ['Arròs', 'Truita'],
            );
          }),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('This ingredient is used in 2 dishes:'), findsOneWidget);
      expect(find.text('• Arròs'), findsOneWidget);
      expect(find.text('• Truita'), findsOneWidget);
      expect(find.textContaining('flagged as not in the catalog'), findsOne);

      // An informed confirmation, not a block: the delete can still proceed,
      // through a button that says so.
      expect(find.text('Delete ingredient'), findsNothing);
      await tester.tap(find.text('Delete anyway'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('the in-use warning can be cancelled, deleting nothing', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          _Opener((context) async {
            result = await showDeleteIngredientDialog(
              context,
              usedIn: const ['Arròs'],
            );
          }),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('This ingredient is used in 1 dish:'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('an unused ingredient gets a clean confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Opener(
            (context) => showDeleteIngredientDialog(context, usedIn: const []),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('This ingredient is used in'), findsNothing);
      expect(
        find.text('It will be removed from your catalog.'),
        findsOneWidget,
      );
      // Nothing about dishes keeping a copy: no dish uses it.
      expect(find.textContaining('dishes'), findsNothing);
      expect(find.textContaining('keep'), findsNothing);
      expect(find.text('Delete ingredient'), findsOneWidget);
      expect(find.text('Delete anyway'), findsNothing);
    });
  });
}
