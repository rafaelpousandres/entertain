/// Spec 020 §2 — a dish option as returned by the `dish-assistant` Edge
/// Function's `search` action. The [raw] map is kept verbatim and sent back on
/// `save` (the server owns the persistence); the parsed fields drive the option
/// card. Names are stored in ca/es/en; the card shows the user's locale.
library;

class DishOption {
  const DishOption({
    required this.raw,
    required this.displayName,
    required this.summary,
    required this.baseServings,
    required this.ingredientNames,
    this.photoUrl,
  });

  /// The full option JSON — sent back unchanged to the `save` action.
  final Map<String, dynamic> raw;

  /// Dish name in the user's locale (falls back across ca/es/en).
  final String displayName;

  /// One-line summary for the card (already in the user's locale).
  final String summary;
  final int baseServings;

  /// Resolved ingredient display names (the server enriches these so the card
  /// needs no catalog lookup).
  final List<String> ingredientNames;

  /// Lead photo URL (web og:image or a Pexels preview), if any.
  final String? photoUrl;

  static String _localized(Map<String, dynamic>? names, String locale) {
    if (names == null) return '';
    return (names[locale] ?? names['ca'] ?? names['es'] ?? names['en'] ?? '')
        .toString();
  }

  factory DishOption.fromJson(
    Map<String, dynamic> json, {
    required String locale,
  }) {
    final names = (json['name'] as Map?)?.cast<String, dynamic>();
    final photo = (json['photo'] as Map?)?.cast<String, dynamic>();
    final ingredientNames =
        (json['ingredient_names'] as List? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
    final servings = json['base_servings'];
    return DishOption(
      raw: json,
      displayName: _localized(names, locale),
      summary: (json['summary'] as String?)?.trim() ?? '',
      baseServings: servings is num ? servings.toInt() : 4,
      ingredientNames: ingredientNames,
      photoUrl: photo?['source_url'] as String?,
    );
  }

  /// The `option` payload the `save` action expects — the untouched search shape.
  Map<String, dynamic> toSavePayload() => raw;
}
