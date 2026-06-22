import 'package:entertain/features/ai_dish_assistant/data/dish_option.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 020 §8 — pure parse of a `search` option into the display model, and
/// the multilingual-name + original-locale handling.
void main() {
  Map<String, dynamic> sampleOption() => {
    'name': {'ca': 'Sípia a la bruta', 'es': 'Sepia sucia', 'en': 'Dirty cuttlefish'},
    'original_locale': 'ca',
    'category': 'main',
    'base_servings': 4,
    'preparation': 'Neteja la sípia…',
    'summary': 'Plat mariner català',
    'photo': {'source_url': 'https://example.test/sipia.jpg', 'author': 'Anna'},
    'ingredient_names': ['Sípia', 'All', 'Oli'],
    'ingredients': [
      {'existing_id': 'ing-1', 'new': null, 'quantity': 400, 'unit_code': 'g'},
    ],
  };

  test('parses display name in the requested locale', () {
    final ca = DishOption.fromJson(sampleOption(), locale: 'ca');
    expect(ca.displayName, 'Sípia a la bruta');
    final es = DishOption.fromJson(sampleOption(), locale: 'es');
    expect(es.displayName, 'Sepia sucia');
    final en = DishOption.fromJson(sampleOption(), locale: 'en');
    expect(en.displayName, 'Dirty cuttlefish');
  });

  test('falls back across locales when the requested one is missing', () {
    final json = sampleOption();
    (json['name'] as Map).remove('es');
    final es = DishOption.fromJson(json, locale: 'es');
    expect(es.displayName, 'Sípia a la bruta'); // ca fallback
  });

  test('reads servings, summary, photo, and key ingredients', () {
    final o = DishOption.fromJson(sampleOption(), locale: 'ca');
    expect(o.baseServings, 4);
    expect(o.summary, 'Plat mariner català');
    expect(o.photoUrl, 'https://example.test/sipia.jpg');
    expect(o.ingredientNames, ['Sípia', 'All', 'Oli']);
  });

  test('null photo and missing servings degrade gracefully', () {
    final json = sampleOption()
      ..['photo'] = null
      ..remove('base_servings');
    final o = DishOption.fromJson(json, locale: 'ca');
    expect(o.photoUrl, isNull);
    expect(o.baseServings, 4); // default
  });

  test('toSavePayload returns the untouched search shape', () {
    final json = sampleOption();
    final o = DishOption.fromJson(json, locale: 'ca');
    expect(o.toSavePayload(), same(json));
    expect(o.toSavePayload()['original_locale'], 'ca');
  });
}
