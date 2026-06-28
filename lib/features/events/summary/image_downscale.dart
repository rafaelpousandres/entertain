/// Spec 027 §C — downscale a stored photo before embedding it in the summary
/// PDF. Including every event/dish/ingredient/drink photo at full resolution
/// (~1600 px JPEGs) would make generation slow and the file huge, so each image
/// is capped to a print-sane longest edge first.
///
/// This wraps the `flutter_image_compress` dependency the app already uses for
/// on-upload compression ([PhotoStorage.compressToJpeg]) — same library, same
/// "minWidth/minHeight is a ceiling, never an upscale" behaviour — so no new
/// image package is pulled in. The compressor runs on a native thread, off the
/// UI isolate, keeping the app responsive while the spinner shows.
library;

import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Longest-edge cap for embedded images (Spec 027 §C: ~800–1000 px / a sane
/// print DPI). Stored originals are bounded to ~1600 px, so this roughly halves
/// the pixel count without visible loss at print size.
const int kSummaryImageMaxEdge = 1000;

/// JPEG quality for embedded images — a touch below the 85 used on upload, as a
/// printed summary tolerates slightly more compression than the in-app viewer.
const int kSummaryImageQuality = 80;

/// Returns [source] re-encoded as a JPEG whose longest edge is at most
/// [maxEdge] px (never upscaled). On any failure the original bytes are returned
/// unchanged — a slightly larger image is preferable to no image, and the PDF
/// still embeds fine.
Future<Uint8List> downscaleForSummaryPdf(
  Uint8List source, {
  int maxEdge = kSummaryImageMaxEdge,
  int quality = kSummaryImageQuality,
}) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      source,
      minWidth: maxEdge,
      minHeight: maxEdge,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    // compressWithList returns the input unchanged rather than null on a no-op,
    // but guard defensively against an empty result.
    return out.isEmpty ? source : out;
  } catch (_) {
    return source;
  }
}
