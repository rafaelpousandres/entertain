import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_repository.dart';
import 'package:entertain/features/photos/data/photo_edit_session.dart';
import 'package:entertain/features/photos/data/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 030 §B — create-mode photo staging. While CREATING a catalog entity the
/// row does not exist yet, so photos are uploaded to a group-keyed staging
/// bucket and tracked on the session; on save they are PROMOTED (a cross-bucket
/// move) into the entity bucket and a `media` row is inserted, in carousel
/// order. On discard the staged blobs are dropped. These tests pin the staged
/// list bookkeeping and the promote→insert round-trip without a live backend.

SupabaseClient _dummyClient() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeStorage extends PhotoStorage {
  _FakeStorage() : super(_dummyClient());

  final List<({String from, String destBucket, String to})> promotions = [];
  final List<({String bucket, List<String> paths})> removals = [];

  @override
  Future<void> promote(String stagedPath, String destBucket, String destPath) async {
    promotions.add((from: stagedPath, destBucket: destBucket, to: destPath));
  }

  @override
  Future<void> remove(String bucket, List<String> paths) async {
    removals.add((bucket: bucket, paths: paths));
  }
}

class _FakeMediaRepo extends MediaRepository {
  _FakeMediaRepo() : super(_dummyClient());

  final List<({String path, int position, String? provider, String? author})>
  inserts = [];

  @override
  Future<void> insert({
    required MediaEntityType type,
    required String entityId,
    required String path,
    required int position,
    String? sourceProvider,
    String? sourceAuthor,
    String? sourceUrl,
    String? sourceRef,
  }) async {
    inserts.add((
      path: path,
      position: position,
      provider: sourceProvider,
      author: sourceAuthor,
    ));
  }
}

PhotoEditSession _session() => PhotoEditSession(
  type: MediaEntityType.ingredient,
  entityId: 'ing-1',
  creating: true,
);

void main() {
  test('addStaged appends in order and marks the session dirty', () {
    final s = _session();
    expect(s.dirty, isFalse);

    s.addStaged('group-1/a.jpg');
    s.addStaged('group-1/b.jpg');

    expect(s.dirty, isTrue);
    expect(s.pendingStaged.map((m) => m.path), ['group-1/a.jpg', 'group-1/b.jpg']);
    expect(s.pendingStaged.map((m) => m.position), [0, 1]);
  });

  test('removeStaged drops the photo and reindexes positions', () {
    final s = _session()
      ..addStaged('group-1/a.jpg')
      ..addStaged('group-1/b.jpg')
      ..addStaged('group-1/c.jpg');

    s.removeStaged(s.pendingStaged[0]);

    expect(s.pendingStaged.map((m) => m.path), ['group-1/b.jpg', 'group-1/c.jpg']);
    expect(s.pendingStaged.map((m) => m.position), [0, 1]);
  });

  test('reorderStaged applies the new order and reindexes', () {
    final s = _session()
      ..addStaged('group-1/a.jpg')
      ..addStaged('group-1/b.jpg');
    final reversed = s.pendingStaged.reversed.toList();

    s.reorderStaged(reversed);

    expect(s.pendingStaged.map((m) => m.path), ['group-1/b.jpg', 'group-1/a.jpg']);
    expect(s.pendingStaged.map((m) => m.position), [0, 1]);
  });

  test('promoteStaged moves each blob to the entity bucket then inserts media, '
      'in order and carrying provenance', () async {
    final storage = _FakeStorage();
    final repo = _FakeMediaRepo();
    final s = _session()
      ..addStaged('group-1/a.jpg')
      ..addStaged(
        'group-1/b.jpg',
        sourceProvider: 'pexels',
        sourceAuthor: 'Alice',
        sourceUrl: 'https://pexels.test/7',
        sourceRef: '7',
      );

    await s.promoteStaged(storage, repo);

    // Two promotions, both out of staging into the ingredient bucket, sourced
    // from the staged paths in carousel order.
    expect(storage.promotions.length, 2);
    expect(storage.promotions[0].from, 'group-1/a.jpg');
    expect(storage.promotions[1].from, 'group-1/b.jpg');
    expect(
      storage.promotions.map((p) => p.destBucket).toSet(),
      {MediaEntityType.ingredient.bucket},
    );
    // The destination path is the real entity path, not the staging path.
    expect(storage.promotions[0].to, startsWith('ing-1/'));

    // A media row per photo, at the same real path, in the same order, with the
    // stock photo's provenance preserved.
    expect(repo.inserts.length, 2);
    expect(repo.inserts[0].position, 0);
    expect(repo.inserts[1].position, 1);
    expect(repo.inserts[0].path, storage.promotions[0].to);
    expect(repo.inserts[1].path, storage.promotions[1].to);
    expect(repo.inserts[0].provider, isNull);
    expect(repo.inserts[1].provider, 'pexels');
    expect(repo.inserts[1].author, 'Alice');

    // The staged list is drained after a successful promotion.
    expect(s.pendingStaged, isEmpty);
  });

  test('discardStaged removes the staged blobs from the staging bucket', () async {
    final storage = _FakeStorage();
    final s = _session()
      ..addStaged('group-1/a.jpg')
      ..addStaged('group-1/b.jpg');

    await s.discardStaged(storage);

    expect(storage.removals.length, 1);
    expect(storage.removals.first.bucket, PhotoStorage.stagingBucket);
    expect(storage.removals.first.paths, ['group-1/a.jpg', 'group-1/b.jpg']);
    expect(s.pendingStaged, isEmpty);
  });
}
