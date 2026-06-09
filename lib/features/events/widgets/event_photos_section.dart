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
class _PhotoRow extends ConsumerWidget {
  const _PhotoRow({required this.eventId, required this.photos});

  final String eventId;
  final List<EventPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: EventPhotosSection.tile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return _AddPhotoTile(
              size: EventPhotosSection.tile,
              onTap: () => addEventPhoto(
                ref: ref,
                context: context,
                eventId: eventId,
              ),
            );
          }
          final photo = photos[index];
          return GestureDetector(
            onTap: () =>
                EventPhotoCarouselScreen.open(context, eventId, index),
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
