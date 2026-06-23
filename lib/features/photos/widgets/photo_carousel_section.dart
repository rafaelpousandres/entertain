import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/media.dart';
import '../data/media_providers.dart';
import '../data/photo_actions.dart';
import '../screens/media_carousel_screen.dart';
import 'photo_image.dart';

/// Reusable photo carousel for any entity (Spec 010 §2.3): a left-justified
/// horizontal thumbnail row in `position` order plus a trailing add tile,
/// shared by the event, dish and ingredient editors. Generalises the Spec 009
/// `EventPhotosSection` to the polymorphic `media` table — only the
/// [MediaEntityType] and the entity id differ between the three editors.
///
/// Tapping a thumbnail opens the full-screen carousel at that photo; the add
/// tile starts the camera/gallery flow; long-press + drag reorders. The first
/// photo by `position` is the cover shown in lists, cards and menu rows.
///
/// Resilience (Spec 009 Fixes §6): an empty carousel and a failed query both
/// render the same placeholder — the add tile alone — never an error or a stuck
/// spinner. A read failure must not block adding the first photo.
class PhotoCarouselSection extends ConsumerWidget {
  const PhotoCarouselSection({
    super.key,
    required this.type,
    required this.entityId,
    this.entityName,
  });

  final MediaEntityType type;
  final String entityId;

  /// Spec 021 §B6: the entity's name, used to prefill the stock-photo search.
  /// Optional — surfaces without a handy name (e.g. events) just omit it.
  final String? entityName;

  static const double tile = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mediaAsync = ref.watch(
      entityMediaProvider((type: type, entityId: entityId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.eventPhotosLabel,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        mediaAsync.when(
          loading: () => const SizedBox(
            height: tile,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: tile,
                height: tile,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            ),
          ),
          // §6: on error fall back to the empty placeholder (just the add tile).
          error: (_, _) =>
              _PhotoRow(
                type: type,
                entityId: entityId,
                entityName: entityName,
                photos: const [],
              ),
          data: (photos) => _PhotoRow(
            type: type,
            entityId: entityId,
            entityName: entityName,
            photos: photos,
          ),
        ),
      ],
    );
  }
}

/// The left-justified horizontal carousel row: each photo as a tappable
/// thumbnail, then a trailing add tile. With no photos it is just the add tile
/// (Spec 009 Fixes §6 empty state). Thumbnails reorder by long-press + drag (a
/// [ReorderableListView] with delayed drag handles); the add tile is pinned and
/// not draggable. Local optimistic state holds the order during/after a drag so
/// the row doesn't snap back while the write and refetch settle; it resyncs from
/// the provider only when the photo *set* changes (an add or remove).
class _PhotoRow extends ConsumerStatefulWidget {
  const _PhotoRow({
    required this.type,
    required this.entityId,
    required this.photos,
    this.entityName,
  });

  final MediaEntityType type;
  final String entityId;
  final String? entityName;
  final List<Media> photos;

  @override
  ConsumerState<_PhotoRow> createState() => _PhotoRowState();
}

class _PhotoRowState extends ConsumerState<_PhotoRow> {
  late List<Media> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
  }

  @override
  void didUpdateWidget(_PhotoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync only when the set of photos changed (add / remove); an order-only
    // difference is the in-flight refresh of a drag we already applied, so keep
    // the local order to avoid reverting it.
    final incomingIds = widget.photos.map((p) => p.id).toSet();
    final localIds = _photos.map((p) => p.id).toSet();
    if (incomingIds.length != localIds.length ||
        !incomingIds.containsAll(localIds)) {
      _photos = List.of(widget.photos);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex >= _photos.length) return;
    newIndex = newIndex.clamp(0, _photos.length - 1);
    if (newIndex == oldIndex) return;
    setState(() {
      final moved = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, moved);
    });
    reorderEntityMedia(
      ref: ref,
      type: widget.type,
      entityId: widget.entityId,
      ordered: _photos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PhotoCarouselSection.tile,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorderItem: _onReorder,
        // Keep the dragged thumbnail clean (no default elevated rectangle).
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        itemCount: _photos.length + 1,
        itemBuilder: (context, index) {
          if (index == _photos.length) {
            // Pinned, non-draggable add tile.
            return Padding(
              key: const ValueKey('add-photo-tile'),
              padding: EdgeInsets.only(left: _photos.isEmpty ? 0 : 8),
              child: _AddPhotoTile(
                size: PhotoCarouselSection.tile,
                onTap: () => addEntityPhoto(
                  ref: ref,
                  context: context,
                  type: widget.type,
                  entityId: widget.entityId,
                  entityName: widget.entityName,
                ),
              ),
            );
          }
          final photo = _photos[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(photo.id),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => MediaCarouselScreen.open(
                  context,
                  widget.type,
                  widget.entityId,
                  index,
                  entityName: widget.entityName,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: PhotoCarouselSection.tile,
                    height: PhotoCarouselSection.tile,
                    child: PhotoBytesImage(
                      photoRef: (bucket: widget.type.bucket, path: photo.path),
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
