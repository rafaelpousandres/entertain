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

/// Circular photo control for the single-photo entities (dish, ingredient —
/// Spec 009 §2.2.4). With no photo it is a `surface-soft` circle with a camera
/// glyph; with a photo it shows the image clipped to the circle. Tapping always
/// invokes [onTap] — the caller opens the options sheet when empty, or the
/// full-screen viewer when a photo is set.
class PhotoAvatarButton extends StatelessWidget {
  const PhotoAvatarButton({
    super.key,
    required this.photoRef,
    required this.onTap,
    this.size = 80,
  });

  /// The stored photo, or null when the entity has none yet.
  final PhotoRef? photoRef;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ref = photoRef;
    return Semantics(
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceSoft,
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ref == null
              ? const Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.accentSecondary,
                )
              : PhotoBytesImage(photoRef: ref),
        ),
      ),
    );
  }
}
