import 'package:entertain/features/events/data/serving_scale.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification 008 §2.10 — quantity scaling and rounding rules.
void main() {
  group('scaleServingQuantity measured (round up to 2 sig figs)', () {
    test('100 g @ 4 → 6 = 150 (already 2 sig figs)', () {
      expect(
        scaleServingQuantity(
          base: 100,
          referenceServings: 4,
          targetServings: 6,
          countable: false,
        ),
        150,
      );
    });

    test('250 g @ 4 → 6 = 375 → 380', () {
      expect(
        scaleServingQuantity(
          base: 250,
          referenceServings: 4,
          targetServings: 6,
          countable: false,
        ),
        380,
      );
    });

    test('same servings is identity', () {
      expect(
        scaleServingQuantity(
          base: 250,
          referenceServings: 4,
          targetServings: 4,
          countable: false,
        ),
        250,
      );
    });

    test('small decimal quantities keep 2 sig figs', () {
      // 2.5 @ 4 → 6 = 3.75 → 3.8
      expect(
        scaleServingQuantity(
          base: 2.5,
          referenceServings: 4,
          targetServings: 6,
          countable: false,
        ),
        closeTo(3.8, 1e-9),
      );
    });
  });

  group('scaleServingQuantity countable (round up to next integer)', () {
    test('1 egg @ 4 → 6 = 1.5 → 2', () {
      expect(
        scaleServingQuantity(
          base: 1,
          referenceServings: 4,
          targetServings: 6,
          countable: true,
        ),
        2,
      );
    });

    test('3 @ 4 → 8 = 6 (whole, unchanged)', () {
      expect(
        scaleServingQuantity(
          base: 3,
          referenceServings: 4,
          targetServings: 8,
          countable: true,
        ),
        6,
      );
    });
  });

  group('scaleServingQuantity defensive', () {
    test('null reference servings means no scaling', () {
      expect(
        scaleServingQuantity(
          base: 250,
          referenceServings: null,
          targetServings: 6,
          countable: false,
        ),
        250,
      );
    });

    test('non-positive reference servings means no scaling', () {
      expect(
        scaleServingQuantity(
          base: 250,
          referenceServings: 0,
          targetServings: 6,
          countable: false,
        ),
        250,
      );
    });
  });
}
