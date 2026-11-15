import 'package:entertain/features/catalog/data/catalog_repository.dart';
import 'package:entertain/features/catalog/data/diet.dart';
import 'package:entertain/features/catalog/data/dish.dart';
import 'package:entertain/features/catalog/data/dish_category.dart';
import 'package:entertain/features/catalog/data/dish_duplicator.dart';
import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_repository.dart';
import 'package:entertain/features/photos/data/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 034 §F1 — duplicating a catalog dish yields a fully independent copy:
/// same fields, recipe lines and photos, sharing no row and no Storage object
/// with the original.

SupabaseClient _client() => SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

const _source = Dish(
  id: 'dish-src',
  groupId: 'group-1',
  name: 'Canelons',
  category: DishCategory.main,
  baseServings: 6,
  acquisitionMode: DishAcquisitionMode.bought,
  supplierCategoryId: 'cat-rostisseria',
  description: 'Els de la iaia',
  preparation: '1. Escalfa.',
  diet: DietLevel.none,
  glutenFree: TriState.no,
);

class _FakeCatalog extends CatalogRepository {
  _FakeCatalog(this.lines) : super(_client());

  final List<DishLineDraft> lines;
  DishDraft? created;
  final List<String> order = [];

  @override
  Future<Dish> fetchDish(String id, String localeCode) async => _source;

  @override
  Future<List<DishLineDraft>> listDishLines(String dishId) async => lines;

  @override
  Future<Dish> createDishCopy(
    DishDraft draft, {
    required String groupId,
    required String localeCode,
  }) async {
    created = draft;
    order.add('dish-row');
    return Dish(
      id: 'dish-copy',
      groupId: groupId,
      name: draft.name,
      category: draft.category,
      baseServings: draft.baseServings,
    );
  }
}

typedef _Row = ({
  String entityId,
  String path,
  int position,
  String? provider,
  String? author,
});

class _FakeMedia extends MediaRepository {
  _FakeMedia(this.sourcePhotos, this.order) : super(_client());

  final List<Media> sourcePhotos;
  final List<String> order;
  final List<_Row> inserted = [];

  @override
  Future<List<Media>> listForEntity(
    MediaEntityType type,
    String entityId,
  ) async => sourcePhotos;

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
    order.add('row:$path');
    inserted.add((
      entityId: entityId,
      path: path,
      position: position,
      provider: sourceProvider,
      author: sourceAuthor,
    ));
  }
}

class _FakeStorage extends PhotoStorage {
  _FakeStorage(this.order, {this.failOn}) : super(_client());

  final List<String> order;
  final String? failOn;
  final List<({String bucket, String from, String to})> copies = [];

  @override
  Future<void> copy(String bucket, String fromPath, String toPath) async {
    if (fromPath == failOn) throw StateError('copy failed');
    order.add('blob:$toPath');
    copies.add((bucket: bucket, from: fromPath, to: toPath));
  }
}

Media _photo(String id, int position, {String? provider, String? author}) =>
    Media(
      id: id,
      entityType: MediaEntityType.dish,
      entityId: 'dish-src',
      path: 'dish-src/$id.jpg',
      position: position,
      sourceProvider: provider,
      sourceAuthor: author,
    );

Future<
  ({
    _FakeCatalog catalog,
    _FakeMedia media,
    _FakeStorage storage,
    ({Dish dish, int photosFailed}) result,
  })
>
_run({List<Media>? photos, String? failOn}) async {
  final catalog = _FakeCatalog([
    DishLineDraft(
      ingredientId: 'ing-1',
      ingredientName: 'Beixamel',
      quantity: 500,
      unitId: 'unit-g',
      prepNote: 'feta a casa',
    ),
    DishLineDraft(
      ingredientId: 'ing-2',
      ingredientName: 'Formatge',
      quantity: 100,
      unitId: 'unit-g',
    ),
  ]);
  final media = _FakeMedia(
    photos ??
        [
          _photo('a', 0, provider: 'pexels', author: 'Ann'),
          _photo('b', 1),
          _photo('c', 2),
        ],
    catalog.order,
  );
  final storage = _FakeStorage(catalog.order, failOn: failOn);
  final result = await duplicateDish(
    catalog: catalog,
    media: media,
    storage: storage,
    sourceDishId: 'dish-src',
    newName: 'Copy of Canelons',
    groupId: 'group-1',
    localeCode: 'en',
  );
  return (catalog: catalog, media: media, storage: storage, result: result);
}

void main() {
  test('copies the dish fields, including the bought-dish supplier', () async {
    final r = await _run();
    final draft = r.catalog.created!;

    expect(draft.name, 'Copy of Canelons');
    expect(draft.category, DishCategory.main);
    expect(draft.baseServings, 6);
    expect(draft.acquisitionMode, DishAcquisitionMode.bought);
    expect(draft.supplierCategoryId, 'cat-rostisseria');
    expect(draft.description, 'Els de la iaia');
    expect(draft.preparation, '1. Escalfa.');
    expect(draft.diet, DietLevel.none);
    expect(draft.glutenFree, TriState.no);
    expect(r.result.dish.id, 'dish-copy');
    expect(r.result.photosFailed, 0);
  });

  test('copies the recipe lines as independent objects', () async {
    final r = await _run();
    final lines = r.catalog.created!.lines;

    expect(lines.map((l) => l.ingredientId), ['ing-1', 'ing-2']);
    expect(lines.first.quantity, 500);
    expect(lines.first.prepNote, 'feta a casa');
    // Not the same instances: editing the copy's line cannot reach the source.
    expect(identical(lines.first, r.catalog.lines.first), isFalse);
    lines.first.quantity = 999;
    expect(r.catalog.lines.first.quantity, 500);
  });

  test('every photo gets its own blob under the new dish — nothing is '
      'shared with the original', () async {
    final r = await _run();
    final sourcePaths = {'dish-src/a.jpg', 'dish-src/b.jpg', 'dish-src/c.jpg'};

    expect(r.storage.copies.map((c) => c.from), sourcePaths.toList());
    expect(r.storage.copies.every((c) => c.bucket == 'dish-photos'), isTrue);

    final newPaths = r.media.inserted.map((m) => m.path).toList();
    expect(newPaths, hasLength(3));
    // Independent objects: none of the copy's rows points at a source blob…
    expect(newPaths.toSet().intersection(sourcePaths), isEmpty);
    // …each one is unique…
    expect(newPaths.toSet(), hasLength(3));
    // …and lives in the copy's own folder, which is what the Storage policy
    // authorises and what a dish delete purges.
    expect(newPaths.every((p) => p.startsWith('dish-copy/')), isTrue);
    expect(r.media.inserted.every((m) => m.entityId == 'dish-copy'), isTrue);
    // The rows reference exactly the blobs that were copied.
    expect(newPaths, r.storage.copies.map((c) => c.to).toList());
  });

  test('keeps the carousel order and the stock-photo attribution', () async {
    final r = await _run();

    expect(r.media.inserted.map((m) => m.position), [0, 1, 2]);
    expect(r.media.inserted.first.provider, 'pexels');
    expect(r.media.inserted.first.author, 'Ann');
    expect(r.media.inserted[1].provider, isNull);
  });

  test('the dish row exists before any blob, and each blob before its row', () async {
    final r = await _run();
    final order = r.catalog.order;

    expect(order.first, 'dish-row');
    for (final path in r.media.inserted.map((m) => m.path)) {
      expect(
        order.indexOf('blob:$path'),
        lessThan(order.indexOf('row:$path')),
        reason: 'a media row must never be written before its blob exists',
      );
    }
  });

  test('a photo that fails to copy is skipped; the rest stay consecutive', () async {
    final r = await _run(failOn: 'dish-src/b.jpg');

    expect(r.result.photosFailed, 1);
    // The dish is still created…
    expect(r.result.dish.id, 'dish-copy');
    // …with the two photos that did copy, and no row for the failed one.
    expect(r.media.inserted, hasLength(2));
    expect(r.media.inserted.map((m) => m.position), [0, 1]);
    expect(r.storage.copies.map((c) => c.from), [
      'dish-src/a.jpg',
      'dish-src/c.jpg',
    ]);
  });

  test('a legacy flat photo path is copied into the new folder layout', () async {
    final r = await _run(
      photos: [
        const Media(
          id: 'legacy',
          entityType: MediaEntityType.dish,
          entityId: 'dish-src',
          path: 'dish-src.jpg',
          position: 0,
        ),
      ],
    );

    expect(r.storage.copies.single.from, 'dish-src.jpg');
    expect(r.media.inserted.single.path, startsWith('dish-copy/'));
  });

  test('a dish without photos duplicates cleanly', () async {
    final r = await _run(photos: const []);
    expect(r.storage.copies, isEmpty);
    expect(r.media.inserted, isEmpty);
    expect(r.result.photosFailed, 0);
  });
}
