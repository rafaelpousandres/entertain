import 'package:entertain/features/shopping/data/message_composer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the supplier message composer after Fixes §2.5 (no event title or date
/// leak into the message) and Fixes round 2 §2.1–§2.2 (a configurable greeting
/// heads the body; each item line carries its preparation note when present).
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

    test('the prep note keeps its original casing', () {
      final line = composeItemLine(
        quantity: '400',
        unit: 'g',
        connector: 'de',
        ingredientName: 'bacallà',
        prepNote: 'Esmicolat',
      );
      expect(line, '400 g de bacallà, Esmicolat');
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
  });
}
