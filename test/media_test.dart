import 'package:entertain/features/photos/data/media.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification 010 §2.4 — the polymorphic media model: the entity-type ↔ wire
/// ↔ bucket mapping and row parsing the app relies on to read/write photos
/// across events, dishes and ingredients.
void main() {
  group('MediaEntityType', () {
    test('wire values match the media_entity_type enum', () {
      expect(MediaEntityType.event.wire, 'event');
      expect(MediaEntityType.dish.wire, 'dish');
      expect(MediaEntityType.ingredient.wire, 'ingredient');
    });

    test('parse round-trips every wire value', () {
      for (final t in MediaEntityType.values) {
        expect(MediaEntityType.parse(t.wire), t);
      }
    });

    test('parse throws on an unknown value rather than guessing', () {
      expect(() => MediaEntityType.parse('person'), throwsArgumentError);
    });

    test('each entity type maps to its storage bucket', () {
      expect(MediaEntityType.event.bucket, 'event-photos');
      expect(MediaEntityType.dish.bucket, 'dish-photos');
      expect(MediaEntityType.ingredient.bucket, 'ingredient-photos');
    });
  });

  group('Media.fromRow', () {
    test('parses a full row', () {
      final media = Media.fromRow({
        'id': 'm1',
        'entity_type': 'dish',
        'entity_id': 'd1',
        'path': 'd1/abc.jpg',
        'position': 2,
      });
      expect(media.id, 'm1');
      expect(media.entityType, MediaEntityType.dish);
      expect(media.entityId, 'd1');
      expect(media.path, 'd1/abc.jpg');
      expect(media.position, 2);
    });

    test('defaults a missing/null position to 0', () {
      final media = Media.fromRow({
        'id': 'm1',
        'entity_type': 'event',
        'entity_id': 'e1',
        'path': 'e1/abc.jpg',
        'position': null,
      });
      expect(media.position, 0);
    });

    test('parses a legacy flat single-photo path', () {
      // Backfilled dish/ingredient photos keep their Spec 009 `{id}.jpg` path.
      final media = Media.fromRow({
        'id': 'm1',
        'entity_type': 'ingredient',
        'entity_id': 'i1',
        'path': 'i1.jpg',
        'position': 0,
      });
      expect(media.path, 'i1.jpg');
      expect(media.entityType.bucket, 'ingredient-photos');
    });
  });
}
