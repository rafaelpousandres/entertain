import 'package:entertain/features/shopping/data/message_composer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the supplier message composer after Fixes §2.5 (no event title or date
/// leak into the message), Fixes round 1 (a configurable greeting heads the
/// body; each item line carries its preparation note when present; the "de"
/// connector elides to "d'" before vowels) and Fixes round 2 §2.3 (the
/// ingredient name and prep note are lowercased on their first character so the
/// line reads as natural Catalan prose).
void main() {
  group('composeMessageBody', () {
    const items = ['500 g de gambes', '2 unit de llimones'];

    test('greeting heads the body, then a blank, then the leading line', () {
      final body = composeMessageBody(
        greeting: 'Hola,',
        leadingLine: 'Per al dia 5 de juny',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(
        body,
        'Hola,\n\nPer al dia 5 de juny\n\n500 g de gambes\n2 unit de llimones'
        '\n\nRafael',
      );
    });

    test('an empty greeting is omitted with no dangling blank', () {
      final body = composeMessageBody(
        greeting: '',
        leadingLine: 'Per al dia 5 de juny',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(
        body,
        'Per al dia 5 de juny\n\n500 g de gambes\n2 unit de llimones\n\nRafael',
      );
    });

    test('a blank-only greeting is treated as empty', () {
      final body = composeMessageBody(
        greeting: '   ',
        leadingLine: '',
        itemLines: items,
        signature: '',
      );
      expect(body, '500 g de gambes\n2 unit de llimones');
    });

    test('greeting with an empty leading line: greeting then items', () {
      final body = composeMessageBody(
        greeting: 'Hola,',
        leadingLine: '',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(
        body,
        'Hola,\n\n500 g de gambes\n2 unit de llimones\n\nRafael',
      );
    });

    test('an empty leading line is omitted with no dangling blank', () {
      final body = composeMessageBody(
        greeting: '',
        leadingLine: '',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(body, '500 g de gambes\n2 unit de llimones\n\nRafael');
    });

    test('an empty signature is omitted', () {
      final body = composeMessageBody(
        greeting: '',
        leadingLine: 'Per al dia 5 de juny',
        itemLines: items,
        signature: '',
      );
      expect(body, 'Per al dia 5 de juny\n\n500 g de gambes\n2 unit de llimones');
    });
  });

  group('composeItemLine', () {
    test('quantity, unit, connector and ingredient', () {
      final line = composeItemLine(
        quantity: '250',
        unit: 'g',
        connector: 'de',
        ingredientName: 'tonyina',
      );
      expect(line, '250 g de tonyina');
    });

    test('a non-empty prep note is appended after a comma', () {
      final line = composeItemLine(
        quantity: '250',
        unit: 'g',
        connector: 'de',
        ingredientName: 'tonyina',
        prepNote: 'tallada a daus petits',
      );
      expect(line, '250 g de tonyina, tallada a daus petits');
    });

    test('an empty or blank prep note adds no trailing clause', () {
      expect(
        composeItemLine(
          quantity: '250',
          unit: 'g',
          connector: 'de',
          ingredientName: 'bacallà dessalat',
          prepNote: '',
        ),
        '250 g de bacallà dessalat',
      );
      expect(
        composeItemLine(
          quantity: '250',
          unit: 'g',
          connector: 'de',
          ingredientName: 'bacallà dessalat',
          prepNote: '   ',
        ),
        '250 g de bacallà dessalat',
      );
    });

    test('the prep note is lowercased on its first character (§2.3)', () {
      final line = composeItemLine(
        quantity: '400',
        unit: 'g',
        connector: 'de',
        ingredientName: 'bacallà',
        prepNote: 'Esmicolat',
      );
      expect(line, '400 g de bacallà, esmicolat');
    });

    test('a null unit drops the connector too (§2.3)', () {
      final line = composeItemLine(
        quantity: '3',
        unit: null,
        connector: 'de',
        ingredientName: 'ous',
      );
      expect(line, '3 ous');
    });

    test('an empty unit drops the connector too (§2.3)', () {
      final line = composeItemLine(
        quantity: '3',
        unit: '',
        connector: 'de',
        ingredientName: 'ous',
      );
      expect(line, '3 ous');
    });

    test('no unit keeps the prep-note clause after a comma (§2.3)', () {
      final line = composeItemLine(
        quantity: '2',
        unit: null,
        connector: 'de',
        ingredientName: 'llimones',
        prepNote: 'tallades a rodanxes',
      );
      expect(line, '2 llimones, tallades a rodanxes');
    });

    test('an empty connector is dropped', () {
      final line = composeItemLine(
        quantity: '250',
        unit: 'g',
        connector: '',
        ingredientName: 'tonyina',
      );
      expect(line, '250 g tonyina');
    });

    group('first-character lowercasing (Fixes round 2 §2.3)', () {
      test('lowercases a Title-Case ingredient name mid-line', () {
        expect(
          composeItemLine(
            quantity: '80',
            unit: 'g',
            connector: 'de',
            ingredientName: 'Anxoves',
            prepNote: 'En oli d\'oliva',
            elideConnector: true,
          ),
          "80 g d'anxoves, en oli d'oliva",
        );
      });

      test('lowercases the name on a no-unit countable line', () {
        expect(
          composeItemLine(
            quantity: '3',
            unit: null,
            connector: 'de',
            ingredientName: 'Ous',
          ),
          '3 ous',
        );
      });

      test('lowercases name and prep note together', () {
        expect(
          composeItemLine(
            quantity: '100',
            unit: 'g',
            connector: 'de',
            ingredientName: 'Llimona',
            prepNote: 'Tallada a rodanxes',
            elideConnector: true,
          ),
          '100 g de llimona, tallada a rodanxes',
        );
      });

      test('only the first character changes; internal capitals are kept', () {
        expect(
          composeItemLine(
            quantity: '1',
            unit: 'unit',
            connector: 'de',
            ingredientName: 'Formatge Manchego',
          ),
          '1 unit de formatge Manchego',
        );
      });
    });

    group('Catalan elision (§2.4)', () {
      test('elides "de" → "d\'" before a vowel', () {
        expect(
          composeItemLine(
            quantity: '200',
            unit: 'g',
            connector: 'de',
            ingredientName: 'oli',
            elideConnector: true,
          ),
          "200 g d'oli",
        );
      });

      test('elides before a silent "h"', () {
        expect(
          composeItemLine(
            quantity: '100',
            unit: 'g',
            connector: 'de',
            ingredientName: 'hortalisses',
            elideConnector: true,
          ),
          "100 g d'hortalisses",
        );
      });

      test('elides before an accented vowel', () {
        expect(
          composeItemLine(
            quantity: '1',
            unit: 'kg',
            connector: 'de',
            ingredientName: 'ànec',
            elideConnector: true,
          ),
          "1 kg d'ànec",
        );
      });

      test('keeps "de" before a consonant', () {
        expect(
          composeItemLine(
            quantity: '250',
            unit: 'g',
            connector: 'de',
            ingredientName: 'tonyina',
            elideConnector: true,
          ),
          '250 g de tonyina',
        );
      });

      test('elision is case-insensitive on the initial', () {
        // §2.3 also lowercases the initial, so a Title-Case catalog name like
        // "Endívies" both triggers the elision and reads as prose.
        expect(
          composeItemLine(
            quantity: '2',
            unit: 'kg',
            connector: 'de',
            ingredientName: 'Endívies',
            elideConnector: true,
          ),
          "2 kg d'endívies",
        );
      });

      test('no elision when the flag is off (default)', () {
        expect(
          composeItemLine(
            quantity: '200',
            unit: 'g',
            connector: 'de',
            ingredientName: 'oli',
          ),
          '200 g de oli',
        );
      });

      test('elision keeps the prep-note clause', () {
        expect(
          composeItemLine(
            quantity: '200',
            unit: 'g',
            connector: 'de',
            ingredientName: 'oli',
            prepNote: 'verge extra',
            elideConnector: true,
          ),
          "200 g d'oli, verge extra",
        );
      });

      test('no unit: nothing to elide, the connector is already dropped', () {
        expect(
          composeItemLine(
            quantity: '3',
            unit: null,
            connector: 'de',
            ingredientName: 'ous',
            elideConnector: true,
          ),
          '3 ous',
        );
      });
    });
  });
}
