import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../events/data/events_providers.dart';
import 'event_photo.dart';
import 'photo_capture.dart';
import 'photo_storage.dart';
import '../screens/photo_viewer_screen.dart';
import '../widgets/photo_source_sheet.dart';

/// Shared photo workflows (Spec 009 §2.2): capture → compress → upload, the
/// single-photo (dish / ingredient) tap behaviour, and the event-album add /
/// remove. Kept in one place so the three entry points stay consistent and the
/// dish and ingredient editors don't duplicate the orchestration.

const _uuid = Uuid();

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

/// The single-photo (dish / ingredient) tap behaviour (Spec §2.2.4 / §2.2.5):
///
/// - with **no** photo, opens the source sheet and, on a capture, uploads to
///   `{entityId}.jpg` and persists the path;
/// - with a photo, opens the full-screen viewer; if the user removes it there,
///   clears the path and deletes the blob.
///
/// [persistPath] writes (or clears) the entity's `photo_path` column;
/// [onChanged] refreshes the caller's providers (the entity + its list) after
/// a change.
Future<void> handleSinglePhotoTap({
  required WidgetRef ref,
  required BuildContext context,
  required String bucket,
  required String entityId,
  required String? currentPath,
  required Future<void> Function(String? path) persistPath,
  required VoidCallback onChanged,
}) async {
  if (currentPath == null) {
    final choice = await showPhotoSourceSheet(context, canRemove: false);
    if (choice == null || !context.mounted) return;
    final source = choice == PhotoSheetChoice.camera
        ? PhotoSource.camera
        : PhotoSource.gallery;
    final uploaded = await _captureCompressAndUpload(
      ref: ref,
      context: context,
      source: source,
      bucket: bucket,
      objectPath: '$entityId.jpg',
    );
    if (uploaded == null) return;
    await persistPath(uploaded);
    onChanged();
  } else {
    final removed = await PhotoViewerScreen.open(context, (
      bucket: bucket,
      path: currentPath,
    ));
    if (!removed) return;
    await persistPath(null);
    try {
      await ref.read(photoStorageProvider).remove(bucket, [currentPath]);
    } catch (_) {
      // Non-fatal (§2.2.7): the row no longer points at the blob; a future
      // sweep can reclaim an orphan.
    }
    ref.invalidate(photoBytesProvider((bucket: bucket, path: currentPath)));
    onChanged();
  }
}

/// Adds a photo to an event's album (Spec §2.2.4/§2.2.5): source sheet →
/// capture → upload to `{eventId}/{uuid}.jpg` → append a row at the end.
/// Returns true on success. Shared by the event detail and the carousel "+".
Future<bool> addEventPhoto({
  required WidgetRef ref,
  required BuildContext context,
  required String eventId,
}) async {
  final choice = await showPhotoSourceSheet(context, canRemove: false);
  if (choice == null || !context.mounted) return false;
  final source = choice == PhotoSheetChoice.camera
      ? PhotoSource.camera
      : PhotoSource.gallery;
  final path = '$eventId/${_uuid.v4()}.jpg';
  final uploaded = await _captureCompressAndUpload(
    ref: ref,
    context: context,
    source: source,
    bucket: PhotoStorage.eventBucket,
    objectPath: path,
  );
  if (uploaded == null) return false;
  // position = current count, so the new photo lands at the end (§2.2.6).
  final existing = await ref.read(eventPhotosProvider(eventId).future);
  await ref
      .read(eventsRepositoryProvider)
      .insertEventPhoto(
        eventId: eventId,
        photoPath: path,
        position: existing.length,
      );
  ref.invalidate(eventPhotosProvider(eventId));
  // The list-screen thumbnail (§6.2) is the first photo; a first-ever add
  // changes it from nothing to this photo.
  ref.invalidate(eventFirstPhotosProvider);
  return true;
}

/// Persists a drag-reordered album (Spec 009 §6.1): writes each photo's new
/// `position` from its index in [ordered], then refreshes the album so the
/// thumbnail row and the carousel pick up the new order. The list-screen
/// thumbnails (first photo per event) are refreshed too, since the first photo
/// may have changed.
Future<void> reorderEventPhotos({
  required WidgetRef ref,
  required String eventId,
  required List<EventPhoto> ordered,
}) async {
  await ref.read(eventsRepositoryProvider).reorderEventPhotos(ordered);
  ref.invalidate(eventPhotosProvider(eventId));
  ref.invalidate(eventFirstPhotosProvider);
}

/// Removes one event photo: deletes the row, then the blob (non-fatal on
/// failure, §2.2.7), and refreshes the album.
Future<void> deleteEventPhoto({
  required WidgetRef ref,
  required EventPhoto photo,
}) async {
  await ref.read(eventsRepositoryProvider).deleteEventPhoto(photo.id);
  try {
    await ref.read(photoStorageProvider).remove(PhotoStorage.eventBucket, [
      photo.photoPath,
    ]);
  } catch (_) {
    // Non-fatal — orphan blob swept later.
  }
  ref.invalidate(eventPhotosProvider(photo.eventId));
  // Removing the current first photo promotes the next one (or none) on the
  // list-screen thumbnail (§6.2).
  ref.invalidate(eventFirstPhotosProvider);
  ref.invalidate(
    photoBytesProvider((bucket: PhotoStorage.eventBucket, path: photo.photoPath)),
  );
}
