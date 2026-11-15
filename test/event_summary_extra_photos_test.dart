import 'dart:typed_data';

import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/summary/event_summary_data.dart';
import 'package:entertain/features/events/summary/event_summary_pdf_builder.dart';
import 'package:entertain/features/events/summary/image_downscale.dart';
import 'package:entertain/features/events/summary/summary_photos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_page_text.dart';

/// Spec 034 §C3 — the summary keeps the cover photo and adds the remaining
/// event and dish photos as small thumbnails, all of them, without disturbing the
/// pagination rules.

// A valid 1×1 transparent PNG — enough for the builder to embed an image.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _labels = EventSummaryLabels(
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
  footer: 'Generat el 15 de novembre',
  badgeVegan: 'VGN',
  badgeVegetarian: 'VGT',
  badgeGlutenFree: 'SG',
);

const _headings = <String>{
  'Convidats',
  'Menú',
  'Compra',
  'Aperitius',
  'Entrants',
  'Plats principals',
  'Postres',
  'Altres',
  'Begudes',
};

/// A paginating menu where the event and every dish carry extra photos.
/// [shim] slides the page boundaries, as in the widowed-heading guard.
EventSummaryData _event({
  int shim = 0,
  bool extras = true,
  int dishExtras = 4,
  int eventExtras = 8,
}) {
  SummaryDish dish(DishCategory c, int n, {int extraSteps = 0}) => SummaryDish(
    name: 'Plat $n',
    category: c,
    servingsLine: '12 racions',
    badges: const [],
    ingredients: [
      for (var i = 1; i <= 3; i++)
        SummaryIngredient(text: 'Ingredient $i · $i kg', badges: const []),
    ],
    photo: _png,
    extraPhotos: extras ? [for (var i = 0; i < dishExtras; i++) _png] : const [],
    preparation: [
      'Prepara-ho.',
      'Cou-ho.',
      'Serveix-ho.',
      for (var s = 1; s <= extraSteps; s++) 'Pas extra $s.',
    ].join('\n'),
  );
  return EventSummaryData(
    eventTitle: 'Dinar de prova',
    eventPhoto: _png,
    eventExtraPhotos: extras
        ? [for (var i = 0; i < eventExtras; i++) _png]
        : const [],
    headerFields: const [SummaryField('Data', 'diumenge, 14 de juny')],
    guestGroups: const [],
    guestsTotal: 0,
    overCapacityNote: null,
    dishes: [
      for (final c in [
        DishCategory.aperitif,
        DishCategory.starter,
        DishCategory.main,
        DishCategory.dessert,
      ])
        for (var n = 1; n <= 3; n++)
          dish(
            c,
            n,
            extraSteps: c == DishCategory.aperitif && n == 1 ? shim : 0,
          ),
    ],
    drinks: const [SummaryDrink(name: 'Vi negre', quantityLine: '3 ampolles')],
    totalsLines: const ['12 plats · 144 racions'],
    suppliers: const [],
  );
}

void main() {
  group('secondaryPhotoPaths', () {
    test('an entity with only a cover has no extras', () {
      expect(secondaryPhotoPaths(null), isEmpty);
      expect(secondaryPhotoPaths(const ['cover.jpg']), isEmpty);
    });

    test('skips the cover and keeps carousel order', () {
      expect(secondaryPhotoPaths(const ['cover.jpg', 'b.jpg', 'c.jpg']), [
        'b.jpg',
        'c.jpg',
      ]);
    });

    test('returns every extra photo, with no cap', () {
      final paths = secondaryPhotoPaths([
        'cover.jpg',
        for (var i = 1; i <= 40; i++) 'p$i.jpg',
      ]);
      expect(paths, hasLength(40));
      expect(paths.first, 'p1.jpg');
      expect(paths.last, 'p40.jpg');
    });
  });

  test('thumbnails shrink as their number grows, and stay subordinate', () {
    for (final count in const [1, 8, 9, 20, 21, 60]) {
      // The size/time constraint: an extra photo costs a fraction of a cover.
      expect(
        summaryThumbMaxEdge(count),
        lessThanOrEqualTo(kSummaryImageMaxEdge ~/ 3),
      );
      // …and they print clearly smaller than the photos they accompany.
      expect(summaryEventThumbSize(count), lessThan(150));
      expect(summaryDishThumbSize(count), lessThan(70));
    }
    expect(summaryEventThumbSize(30), lessThan(summaryEventThumbSize(8)));
    expect(summaryDishThumbSize(30), lessThan(summaryDishThumbSize(4)));
    expect(summaryThumbMaxEdge(30), lessThan(summaryThumbMaxEdge(8)));
  });

  test('the PDF embeds every extra photo and draws no "+N" tile', () async {
    Future<Uint8List> build(EventSummaryData data) =>
        buildEventSummaryPdf(data: data, labels: _labels);
    // The fixture PNG has an alpha channel, so each embedded photo is two
    // image objects: the picture and its soft mask.
    int images(Uint8List pdf) =>
        RegExp(
          r'/Subtype\s*/Image',
        ).allMatches(String.fromCharCodes(pdf)).length ~/
        2;

    final coverOnly = await build(_event(extras: false));
    final few = await build(_event());
    final many = await build(_event(dishExtras: 9, eventExtras: 15));

    // 1 event + 12 dishes: covers only, then +8 / +4 each, then +15 / +9 each.
    expect(images(coverOnly), 13);
    expect(images(few), 13 + 8 + 12 * 4);
    expect(images(many), 13 + 15 + 12 * 9);

    for (final pdf in [coverOnly, few, many]) {
      final text = [
        for (final page in extractPdfTextLines(pdf))
          for (final line in page) line.text,
      ];
      expect(text.where((t) => t.contains('+')), isEmpty);
    }
  });

  test('extra photos never widow a heading, at any pagination phase', () async {
    // The capped counts of the first cut, a real-life load, and a heavy one.
    for (final (dishExtras, eventExtras) in const [(4, 8), (9, 15), (30, 40)]) {
      for (final shim in const [0, 1, 2, 3, 4, 5, 6, 7]) {
        final bytes = await buildEventSummaryPdf(
          data: _event(
            shim: shim,
            dishExtras: dishExtras,
            eventExtras: eventExtras,
          ),
          labels: _labels,
        );
        final pages = extractPdfTextLines(bytes);
        expect(
          pages.length,
          greaterThan(1),
          reason: 'the fixture must paginate for the guard to mean anything',
        );
        for (final page in pages) {
          expect(
            _headings.contains(page.last.text),
            isFalse,
            reason:
                'extras $dishExtras/$eventExtras, shim $shim: a page ends '
                'with the heading "${page.last.text}"',
          );
        }
      }
    }
  });
}
