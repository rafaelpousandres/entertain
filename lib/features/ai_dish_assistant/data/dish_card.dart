/// Spec 020 §2 (v4) — the generated dish card returned by the `dish-assistant`
/// `generate` action, shown for review before saving. [raw] is kept verbatim
/// and sent back to `save`; the parsed fields drive the review UI. Names are
/// stored ca/es/en; the card shows the user's locale.
library;

import '../../catalog/data/dish_category.dart';

/// One reviewed ingredient line. The server enriches each with [displayName],
/// [isNew] (whether it will be created in the catalog), and a localized
/// [unitLabel], so the review needs no catalog lookup.
class DishCardIngredient {
  const DishCardIngredient({
    required this.displayName,
    required this.isNew,
    required this.quantity,
    required this.unitLabel,
    this.prepNote,
  });

  final String displayName;
  final bool isNew;
  final num quantity;
  final String unitLabel;
  final String? prepNote;

  factory DishCardIngredient.fromJson(Map<String, dynamic> json) {
    return DishCardIngredient(
      displayName: (json['display_name'] as String?)?.trim() ?? '',
      isNew: json['is_new'] == true,
      quantity: json['quantity'] is num ? json['quantity'] as num : 0,
      unitLabel: (json['unit_label'] as String?)?.trim() ?? '',
      prepNote: (json['prep_note'] as String?)?.trim().isNotEmpty == true
          ? (json['prep_note'] as String).trim()
          : null,
    );
  }
}

class DishCard {
  const DishCard({
    required this.raw,
    required this.displayName,
    required this.description,
    required this.category,
    required this.baseServings,
    required this.preparation,
    required this.ingredients,
    this.photoPreviewUrl,
  });

  /// The full card JSON — sent back unchanged to the `save` action.
  final Map<String, dynamic> raw;

  final String displayName;
  final String description;
  final DishCategory category;
  final int baseServings;

  /// Numbered-steps recipe (plain text, e.g. "1. …\n2. …").
  final String preparation;
  final List<DishCardIngredient> ingredients;

  /// Pexels preview URL for the review (the full image is downloaded at save).
  final String? photoPreviewUrl;

  static String _localized(Map<String, dynamic>? names, String locale) {
    if (names == null) return '';
    return (names[locale] ?? names['ca'] ?? names['es'] ?? names['en'] ?? '')
        .toString();
  }

  factory DishCard.fromJson(Map<String, dynamic> json, {required String locale}) {
    final names = (json['name'] as Map?)?.cast<String, dynamic>();
    final photo = (json['photo'] as Map?)?.cast<String, dynamic>();
    final servings = json['base_servings'];
    final ingredients = (json['ingredients'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DishCardIngredient.fromJson)
        .toList();
    return DishCard(
      raw: json,
      displayName: _localized(names, locale),
      description: (json['description'] as String?)?.trim() ?? '',
      category: DishCategoryWire.parse((json['category'] as String?) ?? 'other'),
      baseServings: servings is num ? servings.toInt() : 4,
      preparation: (json['preparation'] as String?)?.trim() ?? '',
      ingredients: ingredients,
      photoPreviewUrl: photo?['preview'] as String?,
    );
  }

  /// The `card` payload the `save` action expects — the untouched generate shape.
  Map<String, dynamic> toSavePayload() => raw;

  /// Number of ingredients that will be newly created in the catalog.
  int get newIngredientCount => ingredients.where((i) => i.isNew).length;
}
