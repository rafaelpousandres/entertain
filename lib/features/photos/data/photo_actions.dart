import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../../stock_photos/screens/stock_photo_search_screen.dart';
import 'media.dart';
import 'media_providers.dart';
import 'photo_capture.dart';
import 'photo_edit_session.dart';
import 'photo_storage.dart';
import '../widgets/photo_source_sheet.dart';

/// Shared photo workflows over the polymorphic `media` table (Spec 010 §2.4):
/// capture → compress → upload, then the carousel add / reorder / remove. One
/// implementation for all three entity types (event, dish, ingredient), so the
/// editors share the same orchestration (Spec 010 §2.3).

const _uuid = Uuid();

/// Maps the app language (ca/es/en) to a Pexels search locale (Spec 019 §C.1).
String _pexelsLocale(String languageCode) => switch (languageCode) {
  'ca' => 'ca-ES',
  'es' => 'es-ES',
  _ => 'en-US',
};

/// The active [PhotoEditSession] for an entity, if an editor has one open
/// (Spec 011 §2.6). Null for surfaces with no rollback (e.g. event photos).
PhotoEditSession? _activeSession(
  WidgetRef ref,
  MediaEntityType type,
  String entityId,
) => ref.read(photoEditRegistryProvider).lookup(type, entityId);

/// Captures from [source], compresses to JPEG and uploads to
/// `bucket/objectPath`, invalidating the byte cache for that object. Returns
/// the object path on success, or null on cancel / denied permission / error
/// (the last two surface a snackbar). Permission messaging only applies to the
/// camera; gallery picks go through the Android Photo Picker.
Future<String?> _captureCompressAndUpload({
  required WidgetRef ref,
  required BuildContext context,
  required PhotoSource source,
  required String bucket,
  required String objectPath,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await capturePhoto(source);
  switch (result.status) {
    case CaptureStatus.cancelled:
      return null;
    case CaptureStatus.denied:
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cameraPermissionDeniedBody)),
      );
      return null;
    case CaptureStatus.permanentlyDenied:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.cameraPermissionDeniedBody),
          action: SnackBarAction(
            label: l10n.openSettingsAction,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return null;
    case CaptureStatus.error:
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaveError)));
      return null;
    case CaptureStatus.captured:
      break;
  }
  try {
    final storage = ref.read(photoStorageProvider);
    final bytes = await storage.compressToJpeg(result.filePath!);
    await storage.upload(bucket, objectPath, bytes);
    ref.invalidate(photoBytesProvider((bucket: bucket, path: objectPath)));
    return objectPath;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaveError)));
    return null;
  }
}

/// Adds a photo to an entity's carousel (Spec 010 §2.3/§2.4): source sheet →
/// capture → upload to `{entityId}/{uuid}.jpg` in the entity's bucket → append
/// a `media` row at the end (position = current count). Returns true on success.
Future<bool> addEntityPhoto({
  required WidgetRef ref,
  required BuildContext context,
  required MediaEntityType type,
  required String entityId,
  String? entityName,
}) async {
  final choice = await showPhotoSourceSheet(context, canRemove: false);
  if (choice == null || !context.mounted) return false;
  // Spec 030 §B: while the entity is being CREATED its row does not exist yet,
  // so photos go to the staging bucket (keyed by group) and are tracked on the
  // session; they are promoted to the entity bucket + `media` on save.
  final session = _activeSession(ref, type, entityId);
  final creating = session?.creating ?? false;
  // Spec 019 §C.1: the stock-photo path opens the search screen, which owns the
  // save (via the Edge Function) and the carousel/quota refresh; nothing is
  // added synchronously here.
  if (choice == PhotoSheetChoice.pexels) {
    final locale = _pexelsLocale(Localizations.localeOf(context).languageCode);
    // In create mode the function stages by group, so it needs the group id.
    final groupId = creating
        ? await ref.read(currentGroupIdProvider.future)
        : null;
    if (!context.mounted) return false;
    context.push(
      '/stock-photos',
      extra: StockPhotoSearchArgs(
        type: type,
        entityId: entityId,
        locale: locale,
        // Spec 021 §B6: prefill the search with the entity's name.
        initialQuery: entityName,
        creating: creating,
        groupId: groupId,
      ),
    );
    return false;
  }
  final source = choice == PhotoSheetChoice.camera
      ? PhotoSource.camera
      : PhotoSource.gallery;

  if (creating) {
    final groupId = await ref.read(currentGroupIdProvider.future);
    if (!context.mounted) return false;
    final stagedPath = '$groupId/${_uuid.v4()}.jpg';
    final uploaded = await _captureCompressAndUpload(
      ref: ref,
      context: context,
      source: source,
      bucket: PhotoStorage.stagingBucket,
      objectPath: stagedPath,
    );
    if (uploaded == null) return false;
    session!.addStaged(stagedPath);
    return true;
  }

  final path = '$entityId/${_uuid.v4()}.jpg';
  final uploaded = await _captureCompressAndUpload(
    ref: ref,
    context: context,
    source: source,
    bucket: type.bucket,
    objectPath: path,
  );
  if (uploaded == null) return false;
  final existing = await ref.read(
    entityMediaProvider((type: type, entityId: entityId)).future,
  );
  await ref
      .read(mediaRepositoryProvider)
      .insert(
        type: type,
        entityId: entityId,
        path: path,
        position: existing.length,
      );
  ref.invalidate(entityMediaProvider((type: type, entityId: entityId)));
  // A first-ever add changes the cover shown on the list / menu thumbnails.
  ref.invalidate(entityCoverPathsProvider(type));
  // §2.6: a new photo is an unsaved change the editor can roll back on Discard.
  session?.markDirty();
  return true;
}

/// Persists a drag-reordered carousel (Spec 009 §6.1, generalised): writes each
/// photo's new `position` from its index in [ordered], then refreshes the
/// carousel and the cover thumbnails (the first photo may have changed).
Future<void> reorderEntityMedia({
  required WidgetRef ref,
  required MediaEntityType type,
  required String entityId,
  required List<Media> ordered,
}) async {
  // Spec 030 §B: in create mode the carousel is the session's staged list, not
  // `media` rows — reorder it in place; the new order is applied at promotion.
  final session = _activeSession(ref, type, entityId);
  if (session?.creating ?? false) {
    session!.reorderStaged(ordered);
    return;
  }
  await ref.read(mediaRepositoryProvider).reorder(ordered);
  ref.invalidate(entityMediaProvider((type: type, entityId: entityId)));
  ref.invalidate(entityCoverPathsProvider(type));
  // §2.6: a reorder is an unsaved change the editor can roll back on Discard.
  session?.markDirty();
}

/// Removes a create-mode staged photo (Spec 030 §B): drops it from the session
/// and best-effort deletes its staging blob (the sweeper catches any leftover).
Future<void> removeStagedPhoto({
  required WidgetRef ref,
  required Media media,
}) async {
  final session = _activeSession(ref, media.entityType, media.entityId);
  session?.removeStaged(media);
  try {
    await ref.read(photoStorageProvider).remove(PhotoStorage.stagingBucket, [
      media.path,
    ]);
  } catch (_) {
    // Non-fatal — abandoned staged blobs are swept later.
  }
}

/// Removes one photo: deletes the media row, then the blob (non-fatal on
/// failure, §2.2.7), and refreshes the carousel and cover thumbnails.
Future<void> deleteEntityMedia({
  required WidgetRef ref,
  required Media media,
}) async {
  await ref.read(mediaRepositoryProvider).deleteById(media.id);
  final session = _activeSession(ref, media.entityType, media.entityId);
  if (session != null) {
    // §2.6: inside an editor session, keep the blob in Storage (buffered) so a
    // Discard can restore this photo; it is purged on commit (Save).
    session.deferredBlobs.add(media.path);
    session.markDirty();
  } else {
    try {
      await ref.read(photoStorageProvider).remove(media.entityType.bucket, [
        media.path,
      ]);
    } catch (_) {
      // Non-fatal — orphan blob swept later.
    }
  }
  ref.invalidate(
    entityMediaProvider((type: media.entityType, entityId: media.entityId)),
  );
  ref.invalidate(entityCoverPathsProvider(media.entityType));
  ref.invalidate(
    photoBytesProvider((bucket: media.entityType.bucket, path: media.path)),
  );
}
