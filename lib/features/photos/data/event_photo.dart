/// Domain model for an `event_photos` row (Spec 009 §2.2.6).
library;

class EventPhoto {
  const EventPhoto({
    required this.id,
    required this.eventId,
    required this.photoPath,
    required this.position,
  });

  final String id;
  final String eventId;

  /// Object path inside the `event-photos` bucket: `{event_id}/{photo_id}.jpg`.
  final String photoPath;

  /// Ordering within the carousel; ties broken by `created_at` (handled by the
  /// query's secondary sort).
  final int position;

  factory EventPhoto.fromRow(Map<String, dynamic> row) {
    return EventPhoto(
      id: row['id'] as String,
      eventId: row['event_id'] as String,
      photoPath: row['photo_path'] as String,
      position: (row['position'] as num?)?.toInt() ?? 0,
    );
  }

  static const String selectColumns = 'id, event_id, photo_path, position';
}
