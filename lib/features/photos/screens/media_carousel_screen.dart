import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../data/media.dart';
import '../data/media_providers.dart';
import '../data/photo_actions.dart';
import '../widgets/photo_image.dart';
import '../widgets/photo_remove_confirm.dart';

/// Full-screen carousel for any entity's photos (Spec 010 §2.3, generalising
/// the Spec 009 event carousel): horizontal swipe between photos, pinch-to-zoom
/// on each, a delete action for the current photo, and a "+" to add another.
/// Reads the live [entityMediaProvider] so add / remove reflect immediately;
/// pops back when the carousel becomes empty.
class MediaCarouselScreen extends ConsumerStatefulWidget {
  const MediaCarouselScreen({
    super.key,
    required this.type,
    required this.entityId,
    required this.initialIndex,
    this.entityName,
  });

  final MediaEntityType type;
  final String entityId;
  final int initialIndex;

  /// Spec 021 §B6: the entity's name, threaded to the stock-photo search to
  /// prefill the query when adding a photo from here.
  final String? entityName;

  static Future<void> open(
    BuildContext context,
    MediaEntityType type,
    String entityId,
    int initialIndex, {
    String? entityName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaCarouselScreen(
          type: type,
          entityId: entityId,
          initialIndex: initialIndex,
          entityName: entityName,
        ),
      ),
    );
  }

  @override
  ConsumerState<MediaCarouselScreen> createState() =>
      _MediaCarouselScreenState();
}

class _MediaCarouselScreenState extends ConsumerState<MediaCarouselScreen> {
  late final PageController _controller;
  late int _current;

  MediaTarget get _target => (type: widget.type, entityId: widget.entityId);

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photosAsync = ref.watch(entityMediaProvider(_target));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: l10n.addPhotoAction,
            onPressed: () => addEntityPhoto(
              ref: ref,
              context: context,
              type: widget.type,
              entityId: widget.entityId,
              entityName: widget.entityName,
            ),
          ),
          photosAsync.maybeWhen(
            data: (photos) => IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.photoRemovePhoto,
              onPressed: photos.isEmpty ? null : _removeCurrent,
            ),
            orElse: () => const SizedBox(width: 48),
          ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, _) => Center(
          child: Text(
            l10n.photoLoadError,
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            // Carousel emptied (last photo removed) — return once the frame
            // settles.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
            return const SizedBox.shrink();
          }
          final maxIndex = photos.length - 1;
          if (_current > maxIndex) _current = maxIndex;
          return PhotoViewGallery.builder(
            itemCount: photos.length,
            pageController: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, index) {
              final photo = photos[index];
              return PhotoViewGalleryPageOptions.customChild(
                child: PhotoBytesImage(
                  photoRef: (bucket: widget.type.bucket, path: photo.path),
                  fit: BoxFit.contain,
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                heroAttributes: PhotoViewHeroAttributes(tag: photo.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeCurrent() async {
    final photos = ref.read(entityMediaProvider(_target)).value;
    if (photos == null || photos.isEmpty) return;
    final index = _current.clamp(0, photos.length - 1);
    final confirmed = await showPhotoRemoveConfirm(context);
    if (!confirmed) return;
    await deleteEntityMedia(ref: ref, media: photos[index]);
  }
}
