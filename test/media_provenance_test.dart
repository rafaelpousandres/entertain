import 'package:entertain/features/photos/data/media.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 019 §C.2 — provenance is recorded for stock photos and null otherwise.
void main() {
  test('Media.fromRow reads provenance for a stock photo', () {
    final m = Media.fromRow({
      'id': 'm1',
      'entity_type': 'dish',
      'entity_id': 'd1',
      'path': 'd1/abc.jpg',
      'position': 0,
      'source_provider': 'pexels',
      'source_author': 'Alice Smith',
      'source_url': 'https://www.pexels.com/photo/123/',
      'source_ref': '123',
    });
    expect(m.sourceProvider, 'pexels');
    expect(m.sourceAuthor, 'Alice Smith');
    expect(m.sourceUrl, 'https://www.pexels.com/photo/123/');
    expect(m.sourceRef, '123');
  });

  test('Media.fromRow leaves provenance null for a camera/gallery photo', () {
    final m = Media.fromRow({
      'id': 'm2',
      'entity_type': 'dish',
      'entity_id': 'd1',
      'path': 'd1/def.jpg',
      'position': 1,
      'source_provider': null,
      'source_author': null,
      'source_url': null,
      'source_ref': null,
    });
    expect(m.sourceProvider, isNull);
    expect(m.sourceAuthor, isNull);
    expect(m.sourceUrl, isNull);
    expect(m.sourceRef, isNull);
  });

  test('selectColumns requests the provenance columns', () {
    expect(Media.selectColumns, contains('source_provider'));
    expect(Media.selectColumns, contains('source_ref'));
  });
}
