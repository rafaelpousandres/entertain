import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/catalog/widgets/dish_line_row.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 034 §B2 — the not-in-catalog flag on a dish line and its fix sheet.

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
  group('B2 DishLineDraft.ingredientDeleted', () {
    Map<String, dynamic> row({Object? deletedAt}) => {
      'ingredient_id': 'ing-1',
      'quantity': 200,
      'unit_id': 'unit-g',
      'prep_note': null,
      'ingredients': {
        'name': 'Ceba',
        'diet': 'vegan',
        'gluten_free': 'yes',
        'deleted_at': deletedAt,
      },
    };

    test('is set from the embedded ingredient deleted_at', () {
      expect(DishLineDraft.fromRow(row()).ingredientDeleted, isFalse);
      final deleted = DishLineDraft.fromRow(
        row(deletedAt: '2026-11-13T15:40:00Z'),
      );
      expect(deleted.ingredientDeleted, isTrue);
      // The name is still available to show which ingredient is missing.
      expect(deleted.ingredientName, 'Ceba');
      expect(deleted.copy().ingredientDeleted, isTrue);
    });

    test('is display-only: never written back to dish_ingredients', () {
      final deleted = DishLineDraft.fromRow(row(deletedAt: '2026-11-13'));
      expect(
        deleted.toRow(sortOrder: 0).keys,
        isNot(contains('ingredient_deleted')),
      );
      expect(deleted.toRow(sortOrder: 0)['ingredient_id'], 'ing-1');
    });
  });

  group('B2 DishLineRow', () {
    DishLineDraft line({required bool deleted}) => DishLineDraft(
      ingredientId: 'ing-1',
      ingredientName: 'Ceba',
      quantity: 200,
      unitId: 'unit-g',
      ingredientDeleted: deleted,
    );

    testWidgets('flags a line whose ingredient left the catalog', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DishLineRow(
            line: line(deleted: true),
            unit: null,
            supplierCategory: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Not in the catalog'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('a regular line carries no flag', (tester) async {
      await tester.pumpWidget(
        _app(
          DishLineRow(
            line: line(deleted: false),
            unit: null,
            supplierCategory: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Not in the catalog'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('the fix sheet offers restore and replace', (tester) async {
      MissingIngredientFix? choice;
      await tester.pumpWidget(
        _app(
          _Opener((context) async {
            choice = await showMissingIngredientSheet(
              context,
              ingredientName: 'Ceba',
            );
          }),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('"Ceba" is no longer in the catalog'), findsOneWidget);
      expect(find.text('Replace with another ingredient'), findsOneWidget);
      await tester.tap(find.text('Restore to the catalog'));
      await tester.pumpAndSettle();
      expect(choice, MissingIngredientFix.restore);
    });
  });
}
