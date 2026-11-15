import 'package:uuid/uuid.dart';

import '../../photos/data/media.dart';
import '../../photos/data/media_repository.dart';
import '../../photos/data/photo_storage.dart';
import 'catalog_repository.dart';
import 'dish.dart';

/// Spec 034 §F1 — duplicates a catalog dish into a fully independent copy, to
/// record a variant ("the same dish, but with X changed").
///
/// What carries over: every dish field (category, base servings, description,
/// preparation, dietary attributes and, for a bought dish, its acquisition
/// mode and supplier), the recipe lines (ingredient, quantity, unit, prep note,
/// order) and the photos, in carousel order with their stock-photo
/// attribution. The name is supplied by the caller ("Copy of …"); its
/// translations are regenerated for the new name, as for any created dish.
///
/// **Photos are copied, never shared.** A shared reference is unsafe in this
/// model: removing a photo deletes its Storage object by path (there is no
/// reference count), deleting a dish purges all of its objects, and the Storage
/// policy authorises an object by the dish id in its path. So each photo gets
/// its own object under the new dish's folder (`{newDishId}/{uuid}.jpg`, a
/// server-side copy — the bytes never transit the device) and its own `media`
/// row. From then on adding, removing or reordering photos on one dish cannot
/// touch the other's rows or blobs.
///
/// Ordering guarantees:
///  * the dish row is inserted first — the Storage policy requires the
///    destination dish to exist before an object can be written under its id;
///  * per photo, the object is copied before its `media` row is inserted, so a
///    failure never leaves a row pointing at a missing blob.
///
/// A photo that fails to copy is skipped and counted; the dish is still
/// created and the remaining photos keep consecutive positions.
Future<({Dish dish, int photosFailed})> duplicateDish({
  required CatalogRepository catalog,
  required MediaRepository media,
  required PhotoStorage storage,
  required String sourceDishId,
  required String newName,
  required String groupId,
  required String localeCode,
}) async {
  final source = await catalog.fetchDish(sourceDishId, localeCode);
  final sourceLines = await catalog.listDishLines(sourceDishId);
  final sourcePhotos = await media.listForEntity(
    MediaEntityType.dish,
    sourceDishId,
  );

  final draft = DishDraft.fromDish(source, [
    for (final line in sourceLines) line.copy(),
  ])..name = newName;
  final copy = await catalog.createDishCopy(
    draft,
    groupId: groupId,
    localeCode: localeCode,
  );

  const uuid = Uuid();
  var copied = 0;
  var failed = 0;
  for (final photo in sourcePhotos) {
    final newPath = '${copy.id}/${uuid.v4()}.jpg';
    try {
      await storage.copy(MediaEntityType.dish.bucket, photo.path, newPath);
      await media.insert(
        type: MediaEntityType.dish,
        entityId: copy.id,
        path: newPath,
        position: copied,
        sourceProvider: photo.sourceProvider,
        sourceAuthor: photo.sourceAuthor,
        sourceUrl: photo.sourceUrl,
        sourceRef: photo.sourceRef,
      );
      copied++;
    } catch (_) {
      failed++;
    }
  }
  return (dish: copy, photosFailed: failed);
}
