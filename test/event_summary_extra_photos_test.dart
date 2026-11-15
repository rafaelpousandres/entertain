import 'dart:typed_data';

import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/events/summary/event_summary_data.dart';
import 'package:entertain/features/events/summary/event_summary_pdf_builder.dart';
import 'package:entertain/features/events/summary/image_downscale.dart';
import 'package:entertain/features/events/summary/summary_photos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_page_text.dart';

/// Spec 034 §C3 — the summary keeps the cover photo and adds the remaining
/// event and dish photos as small thumbnails, capped, without disturbing the
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
EventSummaryData _event({int shim = 0, bool extras = true}) {
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
    extraPhotos: extras ? [_png, _png, _png, _png] : const [],
    extraPhotosOverflow: extras ? 1 : 0,
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
    eventExtraPhotos: extras ? [for (var i = 0; i < 8; i++) _png] : const [],
    eventExtraPhotosOverflow: extras ? 7 : 0,
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
      expect(secondaryPhotoPaths(null, max: 4), (
        paths: const <String>[],
        overflow: 0,
      ));
      expect(secondaryPhotoPaths(const ['cover.jpg'], max: 4).paths, isEmpty);
    });

    test('skips the cover and keeps carousel order', () {
      final pick = secondaryPhotoPaths(const [
        'cover.jpg',
        'b.jpg',
        'c.jpg',
      ], max: 4);
      expect(pick.paths, ['b.jpg', 'c.jpg']);
      expect(pick.overflow, 0);
    });

    test('caps the extras and reports how many were left out', () {
      final pick = secondaryPhotoPaths([
        'cover.jpg',
        for (var i = 1; i <= 15; i++) 'p$i.jpg',
      ], max: kSummaryEventExtraPhotos);
      expect(pick.paths.length, kSummaryEventExtraPhotos);
      expect(pick.paths.first, 'p1.jpg');
      expect(pick.overflow, 15 - kSummaryEventExtraPhotos);
    });
  });

  test('secondary thumbnails are embedded far smaller than the cover', () {
    // The size/time constraint: an extra photo costs a fraction of a cover.
    expect(kSummaryThumbMaxEdge, lessThanOrEqualTo(kSummaryImageMaxEdge ~/ 3));
    // …and they print clearly smaller than the photos they accompany.
    expect(kSummaryEventThumbSize, lessThan(150));
    expect(kSummaryDishThumbSize, lessThan(70));
  });

  test('the PDF shows the extra photos and the "+N" overflow tiles', () async {
    final withExtras = await buildEventSummaryPdf(
      data: _event(),
      labels: _labels,
    );
    final coverOnly = await buildEventSummaryPdf(
      data: _event(extras: false),
      labels: _labels,
    );

    final text = [
      for (final page in extractPdfTextLines(withExtras))
        for (final line in page) line.text,
    ];
    // Event strip overflow and one per dish.
    expect(text.where((t) => t.contains('+7')), hasLength(1));
    expect(text.where((t) => t.contains('+1')), hasLength(12));

    // Without extras nothing of the sort is drawn (the summary is as before).
    final plain = [
      for (final page in extractPdfTextLines(coverOnly))
        for (final line in page) line.text,
    ];
    expect(plain.where((t) => t.contains('+')), isEmpty);
  });

  test('extra photos never widow a heading, at any pagination phase', () async {
    for (final shim in const [0, 1, 2, 3, 4, 5, 6, 7]) {
      final bytes = await buildEventSummaryPdf(
        data: _event(shim: shim),
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
          reason: 'shim $shim: a page ends with the heading "${page.last.text}"',
        );
      }
    }
  });
}
