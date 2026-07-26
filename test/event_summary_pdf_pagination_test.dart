import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/summary/event_summary_data.dart';
import 'package:entertain/features/events/summary/event_summary_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_page_text.dart';

/// Release 1.0.29+43 — the widowed-heading regression, frozen end to end.
///
/// The rule under guard: **no section heading (menu course, block title or
/// shopping category) may be the last element of a page**. Unlike the
/// `glueGroups` unit tests, these tests generate a real multi-page document and
/// inspect where the paginated text actually landed, so they also cover the
/// wiring between the glue and `pw.MultiPage` — where the bug lived twice.
void main() {
  const labels = EventSummaryLabels(
    slogan: 'La vida és reunir-se al voltant d\'una taula.',
    sectionGuests: 'Convidats',
    sectionMenu: 'Menú',
    sectionPurchase: 'Compra',
    ingredientsHeading: 'Ingredients',
    preparationHeading: 'Preparació',
    drinksHeading: 'Begudes',
    courseTitles: {
      DishCategory.aperitif: 'Aperitius',
      DishCategory.starter: 'Entrants',
      DishCategory.main: 'Plats principals',
      DishCategory.dessert: 'Postres',
      DishCategory.other: 'Altres',
    },
    totalLabel: 'Total',
    footer: 'Generat el 26 de juliol',
    badgeVegan: 'VGN',
    badgeVegetarian: 'VGT',
    badgeGlutenFree: 'SG',
  );

  /// Every string that renders as a section heading in [bigEvent] below. A
  /// page whose bottom text line is one of these has a widowed heading.
  final headingTexts = <String>{
    'Convidats',
    'Menú',
    'Compra',
    ...['Aperitius', 'Entrants', 'Plats principals', 'Postres', 'Altres'],
    'Begudes',
    for (var s = 1; s <= 30; s++) 'Proveïdor $s',
  };

  /// A menu + shopping list long enough to paginate over several pages, with
  /// headings recurring throughout. [shim] adds that many recipe steps to the
  /// first dish, sliding every later page boundary down by a few points per
  /// step: sweeping it over a small range walks a boundary across a heading,
  /// which is how the red test guarantees a widow without depending on the
  /// exact metrics of one layout.
  EventSummaryData bigEvent({int shim = 0}) {
    SummaryDish dish(DishCategory c, int n, {int extraSteps = 0}) => SummaryDish(
          name: 'Plat $n',
          category: c,
          servingsLine: '12 racions',
          badges: const [],
          ingredients: [
            for (var i = 1; i <= 3; i++)
              SummaryIngredient(text: 'Ingredient $i · $i kg', badges: const []),
          ],
          preparation: [
            'Prepara-ho.',
            'Cou-ho.',
            'Serveix-ho.',
            for (var s = 1; s <= extraSteps; s++) 'Pas extra $s.',
          ].join('\n'),
        );
    return EventSummaryData(
      eventTitle: 'Dinar de prova',
      headerFields: const [SummaryField('Data', 'diumenge, 14 de juny')],
      guestGroups: const [
        SummaryGuestGroup(label: 'Confirmats', names: ['Anna', 'Pau', 'Marc']),
      ],
      guestsTotal: 3,
      overCapacityNote: null,
      dishes: [
        for (final c in [
          DishCategory.aperitif,
          DishCategory.starter,
          DishCategory.main,
          DishCategory.dessert,
        ])
          for (var n = 1; n <= 3; n++)
            dish(c, n,
                extraSteps:
                    c == DishCategory.aperitif && n == 1 ? shim : 0),
      ],
      drinks: const [
        SummaryDrink(name: 'Vi negre', quantityLine: '3 ampolles'),
        SummaryDrink(name: 'Aigua', quantityLine: '6 ampolles'),
      ],
      totalsLines: const ['12 plats · 144 racions'],
      suppliers: [
        for (var s = 1; s <= 30; s++)
          SummarySupplierGroup(
            supplierName: 'Proveïdor $s',
            items: [
              SummaryShoppingItem(name: 'Article $s', measure: '${s * 100} g'),
              if (s.isEven)
                SummaryShoppingItem(name: 'Extra $s', measure: '1 u'),
            ],
          ),
      ],
    );
  }

  /// One step of recipe text is ~11pt and a shopping pair ~38pt, so sweeping
  /// the shim over 0..7 walks every later page boundary across more than one
  /// full heading+content period — some position is guaranteed to land a
  /// boundary right after a heading.
  const shims = [0, 1, 2, 3, 4, 5, 6, 7];

  /// The bottom-most text line of each page.
  Future<List<String>> bottomLines({required bool glue, required int shim}) async {
    final bytes = await buildEventSummaryPdf(
      data: bigEvent(shim: shim),
      labels: labels,
      debugDisableKeepWithNext: !glue,
    );
    final pages = extractPdfTextLines(bytes);
    expect(pages.length, greaterThan(2),
        reason: 'the fixture must paginate for the guard to mean anything');
    return [for (final p in pages) p.last.text];
  }

  group('widowed headings (keep-with-next, end to end)', () {
    test('the detector goes red on the unglued layout', () async {
      // Validates the guard itself: with the glue disabled, sweeping the shim
      // MUST produce at least one page ending in a heading. If layout changes
      // ever make this pass unglued, the fixture needs re-tuning — otherwise
      // the green test proves nothing.
      final widows = <String>[];
      for (final shim in shims) {
        final bottoms = await bottomLines(glue: false, shim: shim);
        widows.addAll(bottoms.where(headingTexts.contains));
      }
      expect(widows, isNotEmpty,
          reason: 'unglued fixture no longer widows any heading; '
              're-tune the fixture so the regression stays observable');
    });

    test('no heading is the last element of any page, at any phase', () async {
      for (final shim in shims) {
        final bottoms = await bottomLines(glue: true, shim: shim);
        for (final bottom in bottoms) {
          expect(headingTexts.contains(bottom), isFalse,
              reason:
                  'shim $shim: a page ends with the widowed heading "$bottom"');
        }
      }
    });
  });

  group('height safeguard', () {
    test('a heading whose first block exceeds a page is not glued', () async {
      // A recipe far taller than an A4: glued to its course title it would be
      // an unbreakable column no page can hold (pw.MultiPage throws on that).
      // The safeguard must drop the glue and let the document build.
      final monster = EventSummaryData(
        eventTitle: 'Sopar',
        headerFields: const [],
        guestGroups: const [],
        guestsTotal: 0,
        overCapacityNote: null,
        dishes: [
          SummaryDish(
            name: 'Plat interminable',
            category: DishCategory.main,
            servingsLine: '12 racions',
            badges: const [],
            ingredients: const [],
            preparation: [
              // Tall enough that title+dish exceed a page, short enough that
              // the dish alone still fits once the safeguard drops the glue.
              for (var i = 1; i <= 50; i++) 'Pas $i, remena i espera.',
            ].join('\n'),
          ),
        ],
        drinks: const [],
        totalsLines: const [],
        suppliers: const [],
      );
      final bytes =
          await buildEventSummaryPdf(data: monster, labels: labels);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('applyGlueHeightGuard splits only the groups that cannot fit', () {
      final groups = [
        [0, 1],
        [2],
        [3, 4, 5],
      ];
      final heights = {0: 30.0, 1: 100.0, 2: 999.0, 3: 30.0, 4: 10.0, 5: 800.0};
      final measured = <int>[];
      final out = applyGlueHeightGuard(
        groups,
        (i) {
          measured.add(i);
          return heights[i]!;
        },
        762,
      );
      expect(out, [
        [0, 1], // fits: kept glued
        [2], // singleton: passes through…
        [3], [4], [5], // 840 > 762: split back into singletons
      ]);
      // …and singletons are never measured.
      expect(measured, isNot(contains(2)));
    });
  });
}
