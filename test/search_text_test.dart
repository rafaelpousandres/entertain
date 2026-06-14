import 'package:entertain/util/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 011 §2.11.d — accent- and case-insensitive search normalisation.

void main() {
  group('foldForSearch (§2.11.d)', () {
    bool matches(String haystack, String query) =>
        foldForSearch(haystack).contains(foldForSearch(query));

    test('"Sípia" is found with any case/accent variant of "sip"', () {
      for (final q in ['Síp', 'síp', 'Sip', 'sip', 'SÍP', 'SIP']) {
        expect(matches('Sípia', q), isTrue, reason: 'query "$q"');
      }
    });

    test('folds the Catalan/Spanish diacritics', () {
      expect(foldForSearch('Mongetes amb cansalada'), 'mongetes amb cansalada');
      expect(foldForSearch('Allioli'), 'allioli');
      expect(foldForSearch('Caçó'), 'caco');
      expect(foldForSearch('Jamón'), 'jamon');
      expect(foldForSearch('Crème'), 'creme');
      expect(foldForSearch('Açúcar'), 'acucar');
    });

    test('lowercases and is idempotent', () {
      expect(foldForSearch('ÀÉÍÒÚ'), 'aeiou');
      expect(foldForSearch(foldForSearch('Sípia')), foldForSearch('Sípia'));
    });

    test('leaves plain ascii unchanged', () {
      expect(foldForSearch('tomatoes'), 'tomatoes');
    });

    test('folds ligatures and sharp s', () {
      expect(foldForSearch('æther'), 'aether');
      expect(foldForSearch('Œuf'), 'oeuf');
      expect(foldForSearch('Straße'), 'strasse');
    });

    test('a non-matching query does not match', () {
      expect(matches('Sípia', 'pop'), isFalse);
    });
  });
}
