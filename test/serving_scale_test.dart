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

    test('small decimal quantities keep 2 sig figs, no float noise', () {
      // 2.5 @ 4 → 6 = 3.75 → 3.8 (exactly, not 3.8000000000000004).
      expect(
        scaleServingQuantity(
          base: 2.5,
          referenceServings: 4,
          targetServings: 6,
          countable: false,
        ),
        3.8,
      );
    });

    test('round-up result is returned without float noise', () {
      // Real-use bug (Spec 008 PR #22): 4.7 @ 2 → 1 = 2.35, which rounds up to
      // 2.4, surfaced in the UI as "2.4000000000000004" because `24 * 0.1`
      // carries binary-float noise. The result must be exactly 2.4.
      expect(
        scaleServingQuantity(
          base: 4.7,
          referenceServings: 2,
          targetServings: 1,
          countable: false,
        ),
        2.4,
      );
    });

    test('reported case: 2 kg roast beef @ 6 → 7 = 2.333… → exactly 2.4', () {
      // Exact reproduction (Spec 008 PR #22, real-use round): a 2 kg line for 6
      // base servings, shown for an event of 7, is 2 / 6 * 7 = 2.333… which
      // rounds up to 2 sig figs as 2.4 — and must be the exact double 2.4, not
      // 2.4000000000000004. Comparing the string form fails if a binary-float
      // tail survives even where == would still pass.
      final scaled = scaleServingQuantity(
        base: 2,
        referenceServings: 6,
        targetServings: 7,
        countable: false,
      );
      expect(scaled, 2.4);
      expect(scaled.toString(), '2.4');
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
