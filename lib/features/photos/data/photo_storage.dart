import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Storage access + on-upload compression for entity photos
/// (Spec 009 §2.2).
///
/// Three private buckets, EU region, gated by RLS so only members of the
/// owning group can read/write (policies in
/// `20260612030000_create_photo_storage_buckets.sql`). Because the buckets are
/// private, display goes through an authenticated **download** of the bytes
/// (cached by [photoBytesProvider]) rather than a public URL — there are no
/// separate thumbnail files (Spec §2.2.3: the full JPEG is reused and scaled
/// down for the 80×80 thumbnail).
class PhotoStorage {
  PhotoStorage(this._client);

  final SupabaseClient _client;

  static const String dishBucket = 'dish-photos';
  static const String ingredientBucket = 'ingredient-photos';
  static const String eventBucket = 'event-photos';
  static const String drinkBucket = 'drink-photos';

  /// Spec 030 §B: holding area for photos added while CREATING a catalog entity,
  /// before its row (and per-entity Storage policy) exists. Keyed by group
  /// (`{group_id}/{uuid}.jpg`), promoted to the entity bucket on save.
  static const String stagingBucket = 'photo-staging';

  /// Compresses a picked image file into a JPEG at quality 85 (Spec §2.2.2).
  /// `image_picker` has already bounded the longest side to 1600 px on pick;
  /// the `minWidth`/`minHeight` ceiling here is a backstop (the library never
  /// upscales) and this step guarantees JPEG output regardless of the source
  /// format. EXIF is dropped — orientation is baked in and the metadata is
  /// dead weight and a small privacy leak (GPS).
  Future<Uint8List> compressToJpeg(String sourcePath) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (bytes == null) {
      throw StateError('Could not compress image at $sourcePath');
    }
    return bytes;
  }

  /// Uploads JPEG bytes to [bucket] at [path], replacing any existing object
  /// (single-photo entities reuse the same `{id}.jpg` name).
  Future<void> upload(String bucket, String path, Uint8List bytes) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
  }

  /// Promotes a staged photo to its entity bucket once the entity row exists
  /// (Spec 030 §B): a single server-side cross-bucket move (copy + delete
  /// source), so the staging blob is gone on success. Throws on failure — the
  /// caller leaves the staged blob for the sweeper and surfaces the error.
  Future<void> promote(String stagedPath, String destBucket, String destPath) {
    return _client.storage
        .from(stagingBucket)
        .move(stagedPath, destPath, destinationBucket: destBucket);
  }

  /// Downloads the raw bytes of a stored object (RLS-checked).
  Future<Uint8List> download(String bucket, String path) {
    return _client.storage.from(bucket).download(path);
  }

  /// Removes objects, ignoring an empty list. Callers treat failures as
  /// non-fatal (Spec §2.2.7: log and continue; orphans are swept later).
  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
  }
}

final photoStorageProvider = Provider<PhotoStorage>((ref) {
  return PhotoStorage(Supabase.instance.client);
});

/// Identifies one stored photo for the byte cache.
typedef PhotoRef = ({String bucket, String path});

/// Downloaded bytes for a stored photo, cached for the session by (bucket,
/// path). Inline thumbnails and the full-screen viewer share the cache, so a
/// photo is fetched once and reused (Spec §2.2.3). Invalidate the matching key
/// after replacing or removing a photo so the next read re-fetches.
final photoBytesProvider = FutureProvider.family<Uint8List, PhotoRef>((
  ref,
  ref_,
) async {
  return ref.watch(photoStorageProvider).download(ref_.bucket, ref_.path);
});
