import 'package:entertain/features/catalog/data/catalog_naming.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 025 Part A / D2 — name localization fallback + the bilingual photo term.
void main() {
  group('localizedName', () {
    test('uses the translated name when present', () {
      expect(localizedName('Orange', 'Taronja'), 'Orange');
    });
    test('falls back to the row name when translation is null or blank', () {
      expect(localizedName(null, 'Taronja'), 'Taronja');
      expect(localizedName('   ', 'Taronja'), 'Taronja');
    });
  });

  group('photoSearchTerm', () {
    test('combines local + English', () {
      expect(photoSearchTerm('Bacallà a la llauna', 'Baked cod'),
          'Bacallà a la llauna Baked cod');
    });
    test('dedupes when identical (case-insensitive)', () {
      expect(photoSearchTerm('Carbonara', 'carbonara'), 'Carbonara');
    });
    test('local only when English is missing', () {
      expect(photoSearchTerm('Taronja', null), 'Taronja');
      expect(photoSearchTerm('Taronja', '  '), 'Taronja');
    });
    test('English only when local is empty', () {
      expect(photoSearchTerm('', 'Orange'), 'Orange');
    });
  });
}
