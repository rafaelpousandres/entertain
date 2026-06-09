import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../photos/data/event_photo.dart';
import '../../photos/data/photo_actions.dart';
import '../../photos/data/photo_storage.dart';
import '../../photos/screens/event_photo_carousel_screen.dart';
import '../../photos/widgets/photo_image.dart';
import '../data/events_providers.dart';

/// Spec 009 §2.2.5: the event's photo album on the Esdeveniment tab — a
/// horizontal thumbnail row in `position` order plus a trailing add tile.
/// Tapping a thumbnail opens the full-screen carousel at that photo; the add
/// tile starts the camera/gallery flow. Watches [eventPhotosProvider] so it
/// refreshes immediately after add / remove.
///
/// Resilience (Spec 009 Fixes §6): an **empty** album and a **failed** query
/// both render the same placeholder — the add tile alone — never an error
/// message or a stuck spinner. The album is an optional memory aid, so a read
/// failure must not block the user from adding the first photo; if the row
/// genuinely can't be listed, the worst case is that an existing photo is
/// momentarily hidden behind the add tile, which the next successful load
/// restores. The underlying read failure that motivated this (the missing
/// `event_photos` GRANT) is fixed at the database level in
/// `20260612040000_grant_event_photos.sql`.
class EventPhotosSection extends ConsumerWidget {
  const EventPhotosSection({super.key, required this.eventId});

  final String eventId;

  static const double tile = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photosAsync = ref.watch(eventPhotosProvider(eventId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.eventPhotosLabel,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        photosAsync.when(
          loading: () => const SizedBox(
            height: tile,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
          // §6: on error fall back to the empty-album placeholder (just the add
          // tile) instead of a confusing "couldn't load the photo" message.
          error: (_, _) => _PhotoRow(eventId: eventId, photos: const []),
          data: (photos) => _PhotoRow(eventId: eventId, photos: photos),
        ),
      ],
    );
  }
}

/// The horizontal album row: each photo as a tappable thumbnail, then a
/// trailing add tile. With no photos it is just the add tile — the empty state
/// (Spec 009 Fixes §6).
///
/// §6.1: the thumbnails reorder by **long-press + drag** (a
/// [ReorderableListView] with delayed drag handles). The trailing add tile is
/// deliberately *not* draggable and stays pinned at the end. A drop persists
/// the new `position` of every photo. Local optimistic state holds the order
/// during and after the drag so the row doesn't snap back while the write and
/// the album refetch settle; it only resyncs from the provider when the photo
/// *set* changes (an add or a remove), never on an order-only refresh, which
/// would otherwise revert the just-applied drag.
class _PhotoRow extends ConsumerStatefulWidget {
  const _PhotoRow({required this.eventId, required this.photos});

  final String eventId;
  final List<EventPhoto> photos;

  @override
  ConsumerState<_PhotoRow> createState() => _PhotoRowState();
}

class _PhotoRowState extends ConsumerState<_PhotoRow> {
  late List<EventPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
  }

  @override
  void didUpdateWidget(_PhotoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync only when the set of photos changed (add / remove); an order-only
    // difference is the in-flight refresh of a drag we already applied, so we
    // keep the local order to avoid reverting it.
    final incomingIds = widget.photos.map((p) => p.id).toSet();
    final localIds = _photos.map((p) => p.id).toSet();
    if (incomingIds.length != localIds.length ||
        !incomingIds.containsAll(localIds)) {
      _photos = List.of(widget.photos);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex for the removed item; we only
    // clamp it so a photo can never land after the pinned add tile.
    // The add tile (last slot) carries no drag listener, but guard anyway.
    if (oldIndex >= _photos.length) return;
    newIndex = newIndex.clamp(0, _photos.length - 1);
    if (newIndex == oldIndex) return;
    setState(() {
      final moved = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, moved);
    });
    reorderEventPhotos(
      ref: ref,
      eventId: widget.eventId,
      ordered: _photos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: EventPhotosSection.tile,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorderItem: _onReorder,
        // Keep the dragged thumbnail clean (no default elevated rectangle
        // behind the rounded image).
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        itemCount: _photos.length + 1,
        itemBuilder: (context, index) {
          if (index == _photos.length) {
            // Pinned, non-draggable add tile.
            return Padding(
              key: const ValueKey('add-photo-tile'),
              padding: const EdgeInsets.only(left: 8),
              child: _AddPhotoTile(
                size: EventPhotosSection.tile,
                onTap: () => addEventPhoto(
                  ref: ref,
                  context: context,
                  eventId: widget.eventId,
                ),
              ),
            );
          }
          final photo = _photos[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(photo.id),
            index: index,
            child: Padding(
              padding: EdgeInsets.only(right: index == _photos.length - 1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => EventPhotoCarouselScreen.open(
                  context,
                  widget.eventId,
                  index,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: EventPhotosSection.tile,
                    height: EventPhotosSection.tile,
                    child: PhotoBytesImage(
                      photoRef: (
                        bucket: PhotoStorage.eventBucket,
                        path: photo.photoPath,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.accentSecondary,
        ),
      ),
    );
  }
}
