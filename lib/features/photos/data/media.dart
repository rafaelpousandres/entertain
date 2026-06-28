/// Domain model for a polymorphic `media` row (Specification 010 §2.4).
///
/// One photo attached to an event, dish or ingredient. The
/// `(entityType, entityId)` pair is the polymorphic foreign key; the storage
/// bucket is implied by [entityType] and the bytes live at [path] inside it.
library;

/// The three entity kinds photos attach to (matches the `media_entity_type`
/// Postgres enum). An earlier Phase 0 design carried a richer `media_owner_type`
/// enum; it was never used and was dropped in Wave 2 (Spec 011 §2.3). Spec 010
/// uses this leaner set.
enum MediaEntityType {
  event('event'),
  dish('dish'),
  ingredient('ingredient'),
  // Spec 014 §2.2: drinks are a photo-bearing catalog entity too.
  drink('drink');

  const MediaEntityType(this.wire);

  /// Database enum value.
  final String wire;

  /// Parses a wire value; throws on an unknown value rather than guessing, so a
  /// schema/code drift surfaces loudly.
  static MediaEntityType parse(String value) {
    for (final t in MediaEntityType.values) {
      if (t.wire == value) return t;
    }
    throw ArgumentError('Unknown media entity type: $value');
  }
}

extension MediaEntityTypeBucket on MediaEntityType {
  /// The Supabase Storage bucket this entity type's photos live in (unchanged
  /// from Spec 009 — the bucket is implied by the entity type).
  String get bucket => switch (this) {
    MediaEntityType.event => 'event-photos',
    MediaEntityType.dish => 'dish-photos',
    MediaEntityType.ingredient => 'ingredient-photos',
    MediaEntityType.drink => 'drink-photos',
  };
}

class Media {
  const Media({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.path,
    required this.position,
    this.sourceProvider,
    this.sourceAuthor,
    this.sourceUrl,
    this.sourceRef,
  });

  final String id;
  final MediaEntityType entityType;
  final String entityId;

  /// Object path inside [MediaEntityTypeBucket.bucket]: the legacy single-photo
  /// `{entity_id}.jpg` (dishes/ingredients before Spec 010) or the multi-photo
  /// `{entity_id}/{photo_id}.jpg`.
  final String path;

  /// Ordering within the carousel; ties broken by `created_at` (handled by the
  /// query's secondary sort).
  final int position;

  /// Spec 019 §C.2: provenance, set only for stock photos (e.g. `pexels`); null
  /// for camera/gallery photos. Written only by the `stock-photos` Edge
  /// Function — the client's own insert path never sets them.
  final String? sourceProvider;
  final String? sourceAuthor;
  final String? sourceUrl;
  final String? sourceRef;

  /// Returns a copy with [position] overridden — used to reindex the staged
  /// carousel (Spec 030 §B) when a create-mode photo is removed or reordered.
  Media copyWith({int? position}) {
    return Media(
      id: id,
      entityType: entityType,
      entityId: entityId,
      path: path,
      position: position ?? this.position,
      sourceProvider: sourceProvider,
      sourceAuthor: sourceAuthor,
      sourceUrl: sourceUrl,
      sourceRef: sourceRef,
    );
  }

  factory Media.fromRow(Map<String, dynamic> row) {
    return Media(
      id: row['id'] as String,
      entityType: MediaEntityType.parse(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      path: row['path'] as String,
      position: (row['position'] as num?)?.toInt() ?? 0,
      sourceProvider: row['source_provider'] as String?,
      sourceAuthor: row['source_author'] as String?,
      sourceUrl: row['source_url'] as String?,
      sourceRef: row['source_ref'] as String?,
    );
  }

  static const String selectColumns =
      'id, entity_type, entity_id, path, position, '
      'source_provider, source_author, source_url, source_ref';
}
