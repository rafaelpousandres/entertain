/// Camera / gallery capture for entity photos (Spec 009 §2.2.4).
///
/// Wraps `image_picker` and the camera runtime permission behind one call.
/// Gallery picks go through the Android Photo Picker, which needs no storage
/// permission; the camera path requests `CAMERA` at first use and reports a
/// permanent denial so the screen can offer a jump to system settings.
///
/// `image_picker`'s `maxWidth` / `maxHeight` bound the longest side to 1600 px
/// on pick (keeping aspect ratio); the authoritative JPEG quality-85 re-encode
/// happens in [PhotoStorage.compressToJpeg] on the returned file.
library;

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum PhotoSource { camera, gallery }

enum CaptureStatus { captured, cancelled, denied, permanentlyDenied, error }

class CaptureResult {
  const CaptureResult(this.status, [this.filePath]);

  final CaptureStatus status;
  final String? filePath;
}

Future<CaptureResult> capturePhoto(PhotoSource source) async {
  if (source == PhotoSource.camera) {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const CaptureResult(CaptureStatus.permanentlyDenied);
    }
    if (!status.isGranted) {
      return const CaptureResult(CaptureStatus.denied);
    }
  }

  try {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return const CaptureResult(CaptureStatus.cancelled);
    return CaptureResult(CaptureStatus.captured, file.path);
  } catch (_) {
    return const CaptureResult(CaptureStatus.error);
  }
}

/// Spec 034 §C1 — how many gallery photos one pick may add. Bounds the work of
/// a single action (each photo is compressed and uploaded in turn) while
/// covering the real need of adding a handful at once.
const int kGalleryMultiPickLimit = 10;

/// Picks several photos from the gallery in one action (Spec 034 §C1), in the
/// order the user selected them. Goes through the Android Photo Picker, so no
/// storage permission is involved. Returns the picked file paths — empty when
/// the user cancelled — or null when the picker itself failed.
///
/// [limit] is enforced twice: passed to the picker (which caps the selection
/// where the platform supports it) and applied to the result, since older
/// picker fallbacks ignore it.
Future<List<String>?> pickGalleryPhotos({
  int limit = kGalleryMultiPickLimit,
}) async {
  try {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      limit: limit,
    );
    return [for (final f in files.take(limit)) f.path];
  } catch (_) {
    return null;
  }
}

/// Spec 034 §C1 — runs [addOne] for each picked photo, in selection order, and
/// reports how many made it. A photo that fails (corrupt file, a dropped
/// upload) is counted and skipped; it never aborts the ones after it.
///
/// [addOne] receives the file path and the number of photos already added in
/// this batch, so the caller can assign consecutive carousel positions without
/// leaving a gap where a photo failed.
Future<({int added, int failed})> addPickedPhotos({
  required List<String> filePaths,
  required Future<void> Function(String filePath, int addedSoFar) addOne,
}) async {
  var added = 0;
  var failed = 0;
  for (final path in filePaths) {
    try {
      await addOne(path, added);
      added++;
    } catch (_) {
      failed++;
    }
  }
  return (added: added, failed: failed);
}
