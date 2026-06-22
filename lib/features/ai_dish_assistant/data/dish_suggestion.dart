/// Spec 020 §2 (v3) — a Phase 1 recipe suggestion from the `dish-assistant`
/// Edge Function's `suggest` action: just a title + source URL. The URL opens
/// in the external browser; "Crea aquest plat" sends it to `process`.
library;

class DishSuggestion {
  const DishSuggestion({required this.title, required this.url});

  final String title;
  final String url;

  factory DishSuggestion.fromJson(Map<String, dynamic> json) {
    return DishSuggestion(
      title: (json['title'] as String?)?.trim() ?? '',
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }

  /// Whether the URL looks like a fetchable web page.
  bool get hasUrl => url.startsWith('http');
}
