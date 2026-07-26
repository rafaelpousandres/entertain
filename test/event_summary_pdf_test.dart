import 'dart:typed_data';

import 'package:entertain/features/catalog/data/diet.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/summary/event_summary_data.dart';
import 'package:entertain/features/events/summary/event_summary_pdf_builder.dart';
import 'package:entertain/features/events/summary/image_downscale.dart';
import 'package:entertain/l10n/app_localizations_ca.dart';
import 'package:entertain/l10n/app_localizations_en.dart';
import 'package:entertain/l10n/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 027 — the PDF builder, its section-omission rules, the dietary badges,
/// and the localized static labels.
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
    footer: 'Fotos d\'stock proporcionades per Pexels. · Generat el 28 de juny',
    badgeVegan: 'VGN',
    badgeVegetarian: 'VGT',
    badgeGlutenFree: 'SG',
  );

  EventSummaryData representative({
    List<SummaryGuestGroup> guests = const [],
    List<SummarySupplierGroup> suppliers = const [],
  }) {
    return EventSummaryData(
      eventTitle: 'Sopar d\'estiu',
      headerFields: const [
        SummaryField('Data', 'diumenge, 14 de juny'),
        SummaryField('Comensals', '12'),
      ],
      guestGroups: guests,
      guestsTotal: guests.fold(0, (s, g) => s + g.count),
      overCapacityNote: null,
      dishes: const [
        SummaryDish(
          name: 'Amanida',
          category: DishCategory.starter,
          servingsLine: '12 racions',
          badges: [DietBadge.vegan, DietBadge.glutenFree],
          ingredients: [
            SummaryIngredient(text: 'Tomàquet · 2 kg', badges: [DietBadge.vegan]),
            SummaryIngredient(text: 'Sal · 10 g', badges: []),
          ],
          preparation: 'Talla-ho tot i barreja-ho.',
        ),
        // A bought dish: name + servings + supplier only, no recipe.
        SummaryDish(
          name: 'Canelons',
          category: DishCategory.main,
          servingsLine: '12 racions',
          badges: [],
          ingredients: [],
          supplierLine: 'Plat preparat · Rostisseria',
        ),
      ],
      drinks: const [
        SummaryDrink(name: 'Vi negre', quantityLine: '3 ampolles', supplierLine: 'Celler'),
      ],
      totalsLines: const ['2 plats · 24 racions · 2 per comensal'],
      suppliers: suppliers,
    );
  }

  final fullSuppliers = [
    const SummarySupplierGroup(
      supplierName: 'Fruiteria',
      items: [SummaryShoppingItem(name: 'Tomàquet', measure: '2 kg')],
    ),
  ];
  final fullGuests = [
    const SummaryGuestGroup(label: 'Confirmats', names: ['Anna', 'Pau']),
    const SummaryGuestGroup(label: 'Pendents', names: ['Marc']),
  ];

  group('buildEventSummaryPdf', () {
    test('produces a non-empty, well-formed PDF for a representative event', () async {
      final bytes = await buildEventSummaryPdf(
        data: representative(guests: fullGuests, suppliers: fullSuppliers),
        labels: labels,
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(1000));
      // PDF magic number "%PDF".
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('still builds when guests and shopping are both empty', () async {
      final data = representative();
      expect(data.hasGuests, isFalse);
      expect(data.hasShopping, isFalse);
      final bytes = await buildEventSummaryPdf(data: data, labels: labels);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('section omission (§E common sense)', () {
    test('no guests → Convidats section is omitted', () {
      expect(representative(guests: const []).hasGuests, isFalse);
      expect(representative(guests: fullGuests).hasGuests, isTrue);
    });

    test('empty shopping → Compra section is omitted', () {
      expect(representative(suppliers: const []).hasShopping, isFalse);
      expect(representative(suppliers: fullSuppliers).hasShopping, isTrue);
    });
  });

  group('dietary badges (Spec 026 + 030 §C)', () {
    test('builder badge abbreviations match the catalog mapping', () {
      // vegan → VGN (vegan ⇒ vegetarian); gluten-free adds SG.
      final badges = dietaryBadgesFor(DietLevel.vegan, TriState.yes);
      expect(badges, [DietBadge.vegan, DietBadge.glutenFree]);
      expect(badges.map(labels.badgeAbbrev).toList(), ['VGN', 'SG']);
      expect(labels.badgeAbbrev(DietBadge.vegetarian), 'VGT');
    });

    test('extended states map to letters (negatives share, "?" literal)', () {
      expect(labels.badgeAbbrev(DietBadge.dietNegative), 'VGT');
      expect(labels.badgeAbbrev(DietBadge.glutenNegative), 'SG');
      expect(labels.badgeAbbrev(DietBadge.unknown), '?');
      // An unclassified dish carries a single "?".
      expect(dietaryBadgesFor(DietLevel.unknown, TriState.unknown),
          [DietBadge.unknown]);
    });
  });

  group('localized static labels follow the locale', () {
    test('section titles + action are translated per locale', () {
      expect(AppLocalizationsCa().summarySectionGuests, 'Convidats');
      expect(AppLocalizationsEs().summarySectionGuests, 'Invitados');
      expect(AppLocalizationsEn().summarySectionGuests, 'Guests');

      expect(AppLocalizationsCa().summaryCreateAction, 'Crea full resum');
      expect(AppLocalizationsEs().summaryCreateAction, 'Crea hoja resumen');
      expect(AppLocalizationsEn().summaryCreateAction, 'Create summary');
    });

    test('footer interpolates the generated-on date', () {
      expect(
        AppLocalizationsEn().summaryFooter('28 June'),
        'Stock photos provided by Pexels. · Generated on 28 June',
      );
    });
  });

  group('file name (§D.5)', () {
    test('preserves the event name spaces and capitals', () {
      expect(eventSummaryFileBase('Dinar Maduixer 260614'), 'Dinar Maduixer 260614');
    });

    test('replaces filesystem-forbidden chars and collapses whitespace', () {
      expect(eventSummaryFileBase('  Sopar: A/B  *  '), 'Sopar A B');
      expect(eventSummaryFileBase('   '), 'resum');
    });
  });

  group('image downscale (§C)', () {
    test('caps the longest edge at the spec value', () {
      expect(kSummaryImageMaxEdge, 1000);
      expect(kSummaryImageQuality, 80);
    });

    test('falls back to the original bytes when compression is unavailable', () async {
      // No platform plugin in a pure unit test → the helper swallows the error
      // and returns the source unchanged rather than dropping the image.
      final src = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final out = await downscaleForSummaryPdf(src);
      expect(out, src);
    });
  });

  group('keep-with-next grouping (§B.1 + rule residual)', () {
    ({bool heading, bool separator}) heading() =>
        (heading: true, separator: false);
    ({bool heading, bool separator}) rule() =>
        (heading: false, separator: true);
    ({bool heading, bool separator}) content() =>
        (heading: false, separator: false);

    test('glues a heading to the content that follows it', () {
      expect(
        glueGroups([heading(), content(), content()]),
        [
          [0, 1],
          [2],
        ],
      );
    });

    test('a heading separated from its content by a rule still reaches it', () {
      // The residual bug: the rule used to satisfy the glue on its own, so the
      // title widowed at the page foot with the rule and the real content
      // started the next page.
      expect(
        glueGroups([heading(), rule(), content(), content()]),
        [
          [0, 1, 2],
          [3],
        ],
      );
    });

    test('crosses a run of several rules and spacers', () {
      expect(
        glueGroups([heading(), rule(), rule(), content()]),
        [
          [0, 1, 2, 3],
        ],
      );
    });

    test('a run of consecutive headings shares one content block', () {
      // Section title + course title + first dish travel together.
      expect(
        glueGroups([heading(), heading(), content(), content()]),
        [
          [0, 1, 2],
          [3],
        ],
      );
    });

    test('only the first follower is glued, so long sections still paginate', () {
      final groups = glueGroups([
        heading(),
        content(),
        content(),
        content(),
      ]);
      expect(groups.first, [0, 1]);
      expect(groups.skip(1).every((g) => g.length == 1), isTrue);
    });

    test('blocks without a heading are left ungrouped', () {
      expect(
        glueGroups([content(), rule(), content()]),
        [
          [0],
          [1],
          [2],
        ],
      );
    });

    test('a trailing heading with no content does not crash', () {
      expect(glueGroups([content(), heading()]), [
        [0],
        [1],
      ]);
      expect(glueGroups([heading(), rule()]), [
        [0, 1],
      ]);
    });

    test('every block appears exactly once, in order', () {
      final flags = [
        heading(),
        rule(),
        content(),
        content(),
        heading(),
        heading(),
        rule(),
        content(),
        rule(),
      ];
      final flat = glueGroups(flags).expand((g) => g).toList();
      expect(flat, List<int>.generate(flags.length, (i) => i));
    });
  });
}
