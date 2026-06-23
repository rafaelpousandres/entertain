import 'package:entertain/features/ai_dish_assistant/data/dish_card.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 020 §8 (v4) — pure parse of a generated dish card: multilingual name +
/// original mark, category, servings, numbered-steps preparation, and the
/// ingredient mapping (existing vs new-flagged).
void main() {
  Map<String, dynamic> sampleCard() => {
    'name': {'ca': 'Carbonara', 'es': 'Carbonara', 'en': 'Carbonara'},
    'original_locale': 'ca',
    'description': 'Pasta italiana amb ou i cansalada.',
    'category': 'main',
    'base_servings': 4,
    'acquisition_mode': 'cooked',
    'preparation': '1. Bull la pasta.\n2. Barreja l\'ou.\n3. Serveix.',
    'photo': {'preview': 'https://example.test/p.jpg', 'full': 'https://example.test/f.jpg'},
    'ingredients': [
      {
        'existing_id': 'ing-pasta',
        'new': null,
        'quantity': 320,
        'unit_code': 'g',
        'prep_note': null,
        'display_name': 'Pasta',
        'is_new': false,
        'unit_label': 'g',
      },
      {
        'existing_id': null,
        'new': {
          'name': {'ca': 'Guanciale', 'es': 'Guanciale', 'en': 'Guanciale'},
          'original_locale': 'es',
          'default_unit_code': 'g',
        },
        'quantity': 150,
        'unit_code': 'g',
        'prep_note': 'a daus',
        'display_name': 'Guanciale',
        'is_new': true,
        'unit_label': 'g',
      },
    ],
  };

  test('parses name (locale), category, servings, description, preparation', () {
    final c = DishCard.fromJson(sampleCard(), locale: 'ca');
    expect(c.displayName, 'Carbonara');
    expect(c.category, DishCategory.main);
    expect(c.baseServings, 4);
    expect(c.description, 'Pasta italiana amb ou i cansalada.');
    expect(c.preparation, contains('1. Bull la pasta.'));
    expect(c.preparation, contains('2. Barreja'));
    expect(c.photoPreviewUrl, 'https://example.test/p.jpg');
  });

  test('ingredient mapping: existing vs new-flagged, with prep note', () {
    final c = DishCard.fromJson(sampleCard(), locale: 'ca');
    expect(c.ingredients.length, 2);
    expect(c.ingredients[0].displayName, 'Pasta');
    expect(c.ingredients[0].isNew, isFalse);
    expect(c.ingredients[0].prepNote, isNull);
    expect(c.ingredients[1].displayName, 'Guanciale');
    expect(c.ingredients[1].isNew, isTrue);
    expect(c.ingredients[1].prepNote, 'a daus');
    expect(c.newIngredientCount, 1);
  });

  test('locale fallback when the requested name is missing', () {
    final json = sampleCard();
    (json['name'] as Map).remove('es');
    final es = DishCard.fromJson(json, locale: 'es');
    expect(es.displayName, 'Carbonara'); // ca fallback
  });

  test('toSavePayload returns the untouched generate shape', () {
    final json = sampleCard();
    final c = DishCard.fromJson(json, locale: 'ca');
    expect(c.toSavePayload(), same(json));
    expect(c.toSavePayload()['original_locale'], 'ca');
  });
}
