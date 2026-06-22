/// Spec 019 §B.1 — a normalized stock photo as returned by the `stock-photos`
/// Edge Function's `search` action. Provider-agnostic shape (Pexels today).
library;

class StockPhoto {
  const StockPhoto({
    required this.id,
    required this.photographer,
    required this.photographerUrl,
    required this.pageUrl,
    required this.alt,
    required this.previewUrl,
    required this.fullUrl,
  });

  /// Provider photo id (stored as `media.source_ref` on save).
  final String id;

  /// Photographer name — shown as the per-photo credit ("Foto de X", §C.1) and
  /// stored as `media.source_author`.
  final String photographer;
  final String photographerUrl;

  /// The provider's photo page — stored as `media.source_url`.
  final String pageUrl;
  final String alt;

  /// Grid thumbnail URL.
  final String previewUrl;

  /// Full-size URL the server downloads and copies into Storage on save.
  final String fullUrl;

  factory StockPhoto.fromJson(Map<String, dynamic> json) {
    final src = (json['src'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StockPhoto(
      id: json['id'].toString(),
      photographer: json['photographer'] as String? ?? '',
      photographerUrl: json['photographer_url'] as String? ?? '',
      pageUrl: json['url'] as String? ?? '',
      alt: json['alt'] as String? ?? '',
      previewUrl: src['preview'] as String? ?? '',
      fullUrl: src['full'] as String? ?? '',
    );
  }

  /// The `photo` payload the Edge Function's `save` action expects.
  Map<String, dynamic> toSavePayload() => {
    'provider': 'pexels',
    'id': id,
    'photographer': photographer,
    'photographer_url': photographerUrl,
    'url': pageUrl,
    'src': {'full': fullUrl, 'preview': previewUrl},
  };
}
