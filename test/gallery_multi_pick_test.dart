import 'package:entertain/features/photos/data/photo_capture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 034 §C1 — several gallery photos are added in one action, in selection
/// order, and one failing photo never aborts the rest.
void main() {
  test('adds every photo in selection order', () async {
    final seen = <String>[];
    final result = await addPickedPhotos(
      filePaths: const ['a.jpg', 'b.jpg', 'c.jpg'],
      addOne: (path, _) async => seen.add(path),
    );

    expect(seen, ['a.jpg', 'b.jpg', 'c.jpg']);
    expect(result, (added: 3, failed: 0));
  });

  test('a failing photo is counted and skipped, the rest still land', () async {
    final seen = <String>[];
    final result = await addPickedPhotos(
      filePaths: const ['a.jpg', 'broken.jpg', 'c.jpg'],
      addOne: (path, _) async {
        if (path == 'broken.jpg') throw StateError('upload failed');
        seen.add(path);
      },
    );

    expect(seen, ['a.jpg', 'c.jpg']);
    expect(result, (added: 2, failed: 1));
  });

  test('carousel positions stay consecutive across a failure', () async {
    // The caller appends at `existing + addedSoFar`; a failure must not leave
    // a hole in the positions.
    const existing = 2;
    final positions = <String, int>{};
    await addPickedPhotos(
      filePaths: const ['a.jpg', 'broken.jpg', 'c.jpg', 'd.jpg'],
      addOne: (path, addedSoFar) async {
        if (path == 'broken.jpg') throw StateError('upload failed');
        positions[path] = existing + addedSoFar;
      },
    );

    expect(positions, {'a.jpg': 2, 'c.jpg': 3, 'd.jpg': 4});
  });

  test('every photo failing reports nothing added', () async {
    final result = await addPickedPhotos(
      filePaths: const ['a.jpg', 'b.jpg'],
      addOne: (_, _) async => throw StateError('offline'),
    );
    expect(result, (added: 0, failed: 2));
  });

  test('the per-action limit is a sane handful', () {
    expect(kGalleryMultiPickLimit, inInclusiveRange(2, 20));
  });
}
