import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../../events/data/events_providers.dart';
import '../data/photo_actions.dart';
import '../data/photo_storage.dart';
import '../widgets/photo_image.dart';
import '../widgets/photo_remove_confirm.dart';

/// Full-screen carousel for an event's photo album (Spec 009 §2.2.5):
/// horizontal swipe between photos, pinch-to-zoom on each, a delete action for
/// the current photo, and a "+" to add another from within the viewer. Reads
/// the live [eventPhotosProvider] so add / remove reflect immediately; pops
/// back to the event detail when the album becomes empty.
class EventPhotoCarouselScreen extends ConsumerStatefulWidget {
  const EventPhotoCarouselScreen({
    super.key,
    required this.eventId,
    required this.initialIndex,
  });

  final String eventId;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    String eventId,
    int initialIndex,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventPhotoCarouselScreen(
          eventId: eventId,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  ConsumerState<EventPhotoCarouselScreen> createState() =>
      _EventPhotoCarouselScreenState();
}

class _EventPhotoCarouselScreenState
    extends ConsumerState<EventPhotoCarouselScreen> {
  late final PageController _controller;
  late int _current;

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
    final photosAsync = ref.watch(eventPhotosProvider(widget.eventId));

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
            onPressed: () => addEventPhoto(
              ref: ref,
              context: context,
              eventId: widget.eventId,
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
            // Album emptied (last photo removed) — return to the detail once
            // the frame settles.
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
                  photoRef: (
                    bucket: PhotoStorage.eventBucket,
                    path: photo.photoPath,
                  ),
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
    final photos = ref.read(eventPhotosProvider(widget.eventId)).value;
    if (photos == null || photos.isEmpty) return;
    final index = _current.clamp(0, photos.length - 1);
    final confirmed = await showPhotoRemoveConfirm(context);
    if (!confirmed) return;
    await deleteEventPhoto(ref: ref, photo: photos[index]);
  }
}
