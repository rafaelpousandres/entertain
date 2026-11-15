import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/media.dart';
import '../data/media_providers.dart';
import '../data/photo_actions.dart';
import '../data/photo_edit_session.dart';
import '../data/photo_storage.dart';
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
    this.searchTerm,
    this.creating = false,
  });

  final MediaEntityType type;
  final String entityId;

  /// Spec 021 §B6 / Spec 031 §B: builds the stock-photo search prefill **at the
  /// moment of opening the search**, so it reflects the live name being typed
  /// (a static string captured at editor-build time went stale — the first open
  /// showed only the initial letter). Optional — surfaces without a handy name
  /// (e.g. events) just omit it.
  final ValueGetter<String?>? searchTerm;

  /// Spec 030 §B: true on a create screen — the carousel renders the session's
  /// staged photos (in the staging bucket) instead of the `media` rows of a
  /// row that does not exist yet.
  final bool creating;

  static const double tile = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final Widget row;
    if (creating) {
      // The host editor rebuilds this subtree on every session change (it
      // listens to the session), so reading the staged list here is live.
      final session = ref
          .read(photoEditRegistryProvider)
          .lookup(type, entityId);
      row = _PhotoRow(
        type: type,
        entityId: entityId,
        searchTerm: searchTerm,
        photos: session?.pendingStaged ?? const [],
        bucket: PhotoStorage.stagingBucket,
        creating: true,
      );
    } else {
      final mediaAsync = ref.watch(
        entityMediaProvider((type: type, entityId: entityId)),
      );
      row = mediaAsync.when(
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
        error: (_, _) => _PhotoRow(
          type: type,
          entityId: entityId,
          searchTerm: searchTerm,
          photos: const [],
          bucket: type.bucket,
        ),
        data: (photos) => _PhotoRow(
          type: type,
          entityId: entityId,
          searchTerm: searchTerm,
          photos: photos,
          bucket: type.bucket,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.eventPhotosLabel,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        row,
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
    required this.bucket,
    this.searchTerm,
    this.creating = false,
  });

  final MediaEntityType type;
  final String entityId;
  final ValueGetter<String?>? searchTerm;
  final List<Media> photos;

  /// Storage bucket the thumbnails are read from: the entity bucket normally,
  /// the staging bucket in create mode (Spec 030 §B).
  final String bucket;

  /// Spec 030 §B: create mode — photos are the session's staged list; tap opens
  /// the staged full-screen viewer and removal drops them from the session.
  final bool creating;

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
        // Spec 034 §C2: the long-press pick-up is confirmed at once — a short
        // vibration plus a visibly "lifted" thumbnail — instead of only
        // becoming apparent when the photo starts to move.
        onReorderStart: (_) => HapticFeedback.mediumImpact(),
        proxyDecorator: (child, _, animation) =>
            PhotoDragProxy(animation: animation, child: child),
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
                  // Spec 031 §B: resolve the live name at tap time.
                  entityName: widget.searchTerm?.call(),
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
                  searchTerm: widget.searchTerm,
                  creating: widget.creating,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: PhotoCarouselSection.tile,
                    height: PhotoCarouselSection.tile,
                    child: PhotoBytesImage(
                      photoRef: (bucket: widget.bucket, path: photo.path),
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

/// Spec 034 §C2 — the look of a carousel thumbnail while it is picked up for
/// reordering: it grows slightly, gains a drop shadow and an accent outline,
/// animated in over the pick-up so the "grabbed" state reads immediately, even
/// before the finger moves.
///
/// The carousel item carries its 8 px trailing gap inside the dragged widget,
/// so the shadow and outline are inset by that gap to hug the photo itself.
class PhotoDragProxy extends StatelessWidget {
  const PhotoDragProxy({
    super.key,
    required this.animation,
    required this.child,
  });

  /// The list's pick-up animation (0 → 1).
  final Animation<double> animation;
  final Widget child;

  /// How much the grabbed thumbnail grows at full lift.
  static const double liftScale = 1.08;

  static const double _gap = 8;
  static final BorderRadius _radius = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: 1 + (liftScale - 1) * t,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Shadow under the photo.
                Positioned.fill(
                  right: _gap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28 * t),
                          blurRadius: 12 * t,
                          offset: Offset(0, 4 * t),
                        ),
                      ],
                    ),
                  ),
                ),
                child!,
                // Accent outline over the photo.
                Positioned.fill(
                  right: _gap,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: _radius,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: t),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
