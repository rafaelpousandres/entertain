import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../data/photo_storage.dart';

/// Renders a stored photo from its downloaded bytes (Spec 009 §2.2.3): the
/// bytes come from [photoBytesProvider] (session-cached, RLS-checked download),
/// scaled to fill the given box. Shows a spinner while loading and a broken-
/// image glyph on error so a missing object never crashes the surface.
class PhotoBytesImage extends ConsumerWidget {
  const PhotoBytesImage({
    super.key,
    required this.photoRef,
    this.fit = BoxFit.cover,
  });

  final PhotoRef photoRef;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(photoBytesProvider(photoRef));
    return bytesAsync.when(
      data: (bytes) => Image.memory(bytes, fit: fit),
      loading: () => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      ),
      error: (_, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.disabled),
      ),
    );
  }
}

/// Small rounded photo thumbnail for catalog list rows (Spec 009 §2.2.3). Sized
/// to sit beside the row's text without inflating the compact card; only shown
/// when the entity actually has a photo, so photo-less rows stay unchanged.
class RowPhotoThumb extends StatelessWidget {
  const RowPhotoThumb({super.key, required this.photoRef, this.size = 44});

  final PhotoRef photoRef;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          color: AppColors.surfaceSoft,
          child: PhotoBytesImage(photoRef: photoRef),
        ),
      ),
    );
  }
}

