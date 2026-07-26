import 'dart:io';

import 'package:entertain/features/catalog/data/diet.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/summary/event_summary_data.dart';
import 'package:entertain/features/events/summary/event_summary_pdf_builder.dart';
import 'package:entertain/l10n/app_localizations_ca.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a review copy of the event summary sheet with the production
/// branding (real fonts + logo) from a fixture equivalent to the
/// "Dinar Maduixer 260614" evidence PDF — long menu, per-supplier shopping
/// list with single-line categories — so the widowed-heading fix can be
/// reviewed visually.
///
/// NOT part of the suite (it lives under tool/, which `flutter test` does not
/// pick up by default). Run it by hand:
///
///     flutter test tool/generate_review_pdf.dart
///
/// Output: build/review/Dinar Maduixer 260614 (review).pdf
void main() {
  test('generate the review summary PDF', () async {
    final l10n = AppLocalizationsCa();
    final labels = EventSummaryLabels(
      slogan: l10n.splashSlogan,
      sectionGuests: l10n.summarySectionGuests,
      sectionMenu: l10n.summarySectionMenu,
      sectionPurchase: l10n.summarySectionPurchase,
      ingredientsHeading: l10n.dishIngredientsSectionTitle,
      preparationHeading: l10n.dishPreparationSectionTitle,
      drinksHeading: l10n.summaryDrinksHeading,
      courseTitles: {
        for (final c in dishCategoryActive) c: dishCategoryLabel(l10n, c),
      },
      totalLabel: l10n.summaryTotalLabel,
      footer: l10n.summaryFooter('26 de juliol de 2026'),
      badgeVegan: l10n.dietBadgeVegan,
      badgeVegetarian: l10n.dietBadgeVegetarian,
      badgeGlutenFree: l10n.dietBadgeGlutenFree,
    );

    SummaryIngredient ing(String text, [List<DietBadge> badges = const []]) =>
        SummaryIngredient(text: text, badges: badges);

    final data = EventSummaryData(
      eventTitle: 'Dinar Maduixer 260614',
      headerFields: const [
        SummaryField('Data', 'diumenge, 14 de juny de 2026'),
        SummaryField('Hora', '14.00'),
        SummaryField('Lloc', 'Casa Maduixer'),
        SummaryField('Comensals', '12'),
      ],
      guestGroups: const [
        SummaryGuestGroup(
          label: 'Confirmats',
          names: ['Anna', 'Pau', 'Marc', 'Laia', 'Júlia', 'Pere', 'Rosa', 'Quim'],
        ),
        SummaryGuestGroup(label: 'Pendents', names: ['Berta', 'Oriol']),
      ],
      guestsTotal: 10,
      overCapacityNote: null,
      dishes: [
        SummaryDish(
          name: 'Carpaccio de vedella',
          category: DishCategory.starter,
          servingsLine: '12 racions',
          badges: const [DietBadge.glutenFree],
          ingredients: [
            ing('Vedella (filet) · 600 g'),
            ing('Parmesà · 120 g', const [DietBadge.vegetarian]),
            ing('Ruca · 100 g', const [DietBadge.vegan]),
            ing('Oli d\'oliva verge · 6 c.s.', const [DietBadge.vegan]),
            ing('Llimona · 2 u', const [DietBadge.vegan]),
          ],
          preparation: 'Congela lleugerament el filet per poder-lo tallar fi.\n'
              'Talla làmines molt fines i disposa-les al plat.\n'
              'Amaneix amb oli, llimona, sal i pebre.\n'
              'Acaba amb encenalls de parmesà i ruca.',
        ),
        SummaryDish(
          name: 'Amanida de tomàquet i burrata',
          category: DishCategory.starter,
          servingsLine: '12 racions',
          badges: const [DietBadge.vegetarian, DietBadge.glutenFree],
          ingredients: [
            ing('Tomàquet de penjar · 2 kg', const [DietBadge.vegan]),
            ing('Burrata · 4 u', const [DietBadge.vegetarian]),
            ing('Alfàbrega fresca · 1 manat', const [DietBadge.vegan]),
            ing('Oli d\'oliva verge · 6 c.s.', const [DietBadge.vegan]),
          ],
          preparation: 'Talla el tomàquet a grills i salpebra\'l.\n'
              'Esquinça la burrata per sobre.\n'
              'Acaba amb alfàbrega i un bon raig d\'oli.',
        ),
        SummaryDish(
          name: 'Musclos al vapor',
          category: DishCategory.starter,
          servingsLine: '12 racions',
          badges: const [DietBadge.glutenFree],
          ingredients: [
            ing('Musclos · 3 kg'),
            ing('Llorer · 2 fulles', const [DietBadge.vegan]),
            ing('Llimona · 2 u', const [DietBadge.vegan]),
          ],
          preparation: 'Neteja els musclos i descarta els oberts.\n'
              'Obre\'ls al vapor amb el llorer.\n'
              'Serveix-los amb llimona.',
        ),
        SummaryDish(
          name: 'Arròs de marisc',
          category: DishCategory.main,
          servingsLine: '12 racions',
          badges: const [DietBadge.glutenFree],
          ingredients: [
            ing('Arròs bomba · 1,2 kg', const [DietBadge.vegan]),
            ing('Gamba vermella · 24 u'),
            ing('Escamarlans · 12 u'),
            ing('Sípia · 1 kg'),
            ing('Brou de peix · 3 l'),
            ing('Tomàquet ratllat · 400 g', const [DietBadge.vegan]),
            ing('All · 6 grans', const [DietBadge.vegan]),
            ing('Nyora · 3 u', const [DietBadge.vegan]),
            ing('Safrà · 1 sobre', const [DietBadge.vegan]),
          ],
          preparation: 'Sofregeix la sípia fins que quedi rossa.\n'
              'Afegeix l\'all, la nyora i el tomàquet; sofregeix lentament.\n'
              'Marca les gambes i els escamarlans i reserva\'ls.\n'
              'Tira l\'arròs i nacra\'l un parell de minuts.\n'
              'Mulla amb el brou calent i el safrà; no remenis més.\n'
              'Als 10 minuts, col·loca el marisc reservat per sobre.\n'
              'Acaba 8 minuts més i deixa reposar 5 minuts tapat.',
        ),
        SummaryDish(
          name: 'Costelles de xai al forn',
          category: DishCategory.main,
          servingsLine: '12 racions',
          badges: const [DietBadge.glutenFree],
          ingredients: [
            ing('Costelles de xai · 2,5 kg'),
            ing('Patata · 2 kg', const [DietBadge.vegan]),
            ing('Romaní · 3 branques', const [DietBadge.vegan]),
            ing('Vi blanc · 200 ml', const [DietBadge.vegan]),
          ],
          preparation: 'Enforna les patates tallades amb oli i romaní.\n'
              'Quan agafin color, afegeix les costelles salpebrades.\n'
              'Rega amb el vi i acaba al grill.',
        ),
        SummaryDish(
          name: 'Pastís de maduixa',
          category: DishCategory.dessert,
          servingsLine: '12 racions',
          badges: const [DietBadge.vegetarian],
          ingredients: [
            ing('Maduixes · 1 kg', const [DietBadge.vegan]),
            ing('Nata per muntar · 500 ml', const [DietBadge.vegetarian]),
            ing('Base de pa de pessic · 2 u'),
          ],
          preparation: 'Munta la nata ben freda.\n'
              'Alterna capes de pa de pessic, nata i maduixa.\n'
              'Reserva a la nevera un mínim de 2 hores.',
        ),
        const SummaryDish(
          name: 'Macedònia de fruita',
          category: DishCategory.dessert,
          servingsLine: '12 racions',
          badges: [DietBadge.vegan, DietBadge.glutenFree],
          ingredients: [],
          supplierLine: 'Plat preparat · Fruiteria Cal Pagès',
        ),
      ],
      drinks: const [
        SummaryDrink(
            name: 'Vi blanc (verdejo)',
            quantityLine: '4 ampolles',
            supplierLine: 'Celler del Poble'),
        SummaryDrink(
            name: 'Vi negre (criança)',
            quantityLine: '3 ampolles',
            supplierLine: 'Celler del Poble'),
        SummaryDrink(name: 'Aigua amb gas', quantityLine: '6 ampolles'),
        SummaryDrink(name: 'Cervesa', quantityLine: '12 llaunes'),
        SummaryDrink(name: 'Cafè', quantityLine: '1 paquet'),
      ],
      totalsLines: const ['7 plats · 84 racions · 7 per comensal'],
      suppliers: const [
        SummarySupplierGroup(supplierName: 'Fruiteria', items: [
          SummaryShoppingItem(name: 'Tomàquet de penjar', measure: '2 kg'),
          SummaryShoppingItem(name: 'Maduixes', measure: '1 kg'),
          SummaryShoppingItem(name: 'Llimona', measure: '4 u'),
          SummaryShoppingItem(name: 'Ruca', measure: '100 g'),
          SummaryShoppingItem(name: 'Alfàbrega fresca', measure: '1 manat'),
          SummaryShoppingItem(name: 'Patata', measure: '2 kg'),
        ]),
        SummarySupplierGroup(supplierName: 'Peixateria', items: [
          SummaryShoppingItem(name: 'Gamba vermella', measure: '24 u'),
          SummaryShoppingItem(name: 'Escamarlans', measure: '12 u'),
          SummaryShoppingItem(name: 'Sípia', measure: '1 kg'),
          SummaryShoppingItem(name: 'Musclos', measure: '3 kg'),
        ]),
        SummarySupplierGroup(supplierName: 'Carnisseria', items: [
          SummaryShoppingItem(name: 'Vedella (filet)', measure: '600 g'),
          SummaryShoppingItem(name: 'Costelles de xai', measure: '2,5 kg'),
        ]),
        SummarySupplierGroup(supplierName: 'Xarcuteria', items: [
          SummaryShoppingItem(name: 'Parmesano', measure: '200 g'),
        ]),
        SummarySupplierGroup(supplierName: 'Formatgeria', items: [
          SummaryShoppingItem(name: 'Burrata', measure: '4 u'),
        ]),
        SummarySupplierGroup(supplierName: 'Celler', items: [
          SummaryShoppingItem(name: 'Vi blanc (verdejo)', measure: '4 ampolles'),
          SummaryShoppingItem(name: 'Vi negre (criança)', measure: '3 ampolles'),
        ]),
        SummarySupplierGroup(supplierName: 'Supermercat', items: [
          SummaryShoppingItem(name: 'Arròs bomba', measure: '1,2 kg'),
          SummaryShoppingItem(name: 'Brou de peix', measure: '3 l'),
          SummaryShoppingItem(name: 'Nata per muntar', measure: '500 ml'),
          SummaryShoppingItem(name: 'Base de pa de pessic', measure: '2 u'),
          SummaryShoppingItem(name: 'Aigua amb gas', measure: '6 ampolles'),
          SummaryShoppingItem(name: 'Cervesa', measure: '12 llaunes'),
          SummaryShoppingItem(name: 'Cafè', measure: '1 paquet'),
          SummaryShoppingItem(name: 'Safrà', measure: '1 sobre'),
          SummaryShoppingItem(name: 'Oli d\'oliva verge', measure: '1 l'),
        ]),
      ],
    );

    final fonts = EventSummaryFonts(
      base: pw.Font.ttf(
          File('assets/fonts/NunitoSans-Regular.ttf').readAsBytesSync().buffer.asByteData()),
      bold: pw.Font.ttf(
          File('assets/fonts/NunitoSans-Medium.ttf').readAsBytesSync().buffer.asByteData()),
      title: pw.Font.ttf(
          File('assets/fonts/Fraunces-Regular.ttf').readAsBytesSync().buffer.asByteData()),
    );
    final logo =
        File('assets/icon/entertain - icon foreground.png').readAsBytesSync();

    final bytes = await buildEventSummaryPdf(
      data: data,
      labels: labels,
      logo: logo,
      fonts: fonts,
    );

    final out = File('build/review/Dinar Maduixer 260614 (review).pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(10000));
    // ignore: avoid_print
    print('written: ${out.path} (${bytes.length} bytes)');
  });
}
