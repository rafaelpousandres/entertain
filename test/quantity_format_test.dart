import 'package:entertain/features/catalog/data/dish.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 008 §2.10 (PR #22) — [formatQuantity] is the single funnel every
/// quantity passes through before reaching the user, so besides cosmetic
/// trimming it scrubs any residual IEEE-754 noise: even if a future calc forgets
/// to round, the user must never see "2.4000000000000004".
void main() {
  group('formatQuantity — IEEE-754 noise defense', () {
    test('a multiplication tail (2.4000000000000004) renders as "2.4"', () {
      expect(formatQuantity(2.4000000000000004), '2.4');
    });

    test('a subtraction tail (1.4 - 1.0 = 0.3999999999999999) renders as "0.4"',
        () {
      expect(formatQuantity(1.4 - 1.0), '0.4');
    });

    test('an integer that carries noise (2.0000000000000004) renders as "2"',
        () {
      expect(formatQuantity(2.0000000000000004), '2');
    });
  });

  group('formatQuantity — trailing zeros and integers', () {
    test('whole numbers drop the decimal point', () {
      expect(formatQuantity(200), '200');
      expect(formatQuantity(2.0), '2');
    });

    test('trailing zeros are dropped (2.40 → 2.4)', () {
      expect(formatQuantity(2.40), '2.4');
    });

    test('genuine fractional precision is preserved', () {
      expect(formatQuantity(0.5), '0.5');
      expect(formatQuantity(0.125), '0.125');
      expect(formatQuantity(2.35), '2.35');
    });

    test('zero renders as "0"', () {
      expect(formatQuantity(0), '0');
    });
  });

  group('formatQuantity — locale decimal separator', () {
    test('default separator is a point', () {
      expect(formatQuantity(2.4), '2.4');
    });

    test('Catalan/Spanish use a comma', () {
      final sep = quantityDecimalSeparator('ca');
      expect(sep, ',');
      expect(formatQuantity(2.4, decimalSeparator: sep), '2,4');
      expect(
        formatQuantity(2.4000000000000004,
            decimalSeparator: quantityDecimalSeparator('es')),
        '2,4',
      );
    });

    test('English uses a point', () {
      expect(quantityDecimalSeparator('en'), '.');
      expect(
        formatQuantity(2.4, decimalSeparator: quantityDecimalSeparator('en')),
        '2.4',
      );
    });

    test('the separator never touches an integer value', () {
      expect(formatQuantity(200, decimalSeparator: ','), '200');
    });
  });
}
