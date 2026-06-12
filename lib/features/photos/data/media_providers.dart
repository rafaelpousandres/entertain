import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media.dart';
import 'media_repository.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(Supabase.instance.client);
});

/// Identifies one entity's media list for the family provider.
typedef MediaTarget = ({MediaEntityType type, String entityId});

/// An entity's photos in carousel order (Spec 010 §2.4). `autoDispose` so the
/// carousel re-reads from the source of truth each time it is shown; the
/// add / remove / reorder actions invalidate it explicitly to refresh in place.
final entityMediaProvider =
    FutureProvider.autoDispose.family<List<Media>, MediaTarget>((
  ref,
  target,
) async {
  return ref
      .watch(mediaRepositoryProvider)
      .listForEntity(target.type, target.entityId);
});

/// Cover photo (first by carousel order) per entity of a type, as a map of
/// entity id → object path (Spec 010 §2.4 / §2.3). Drives the list / card /
/// menu thumbnails. Invalidated by the photo actions when a cover may change.
final entityCoverPathsProvider =
    FutureProvider.family<Map<String, String>, MediaEntityType>((
  ref,
  type,
) async {
  return ref.watch(mediaRepositoryProvider).coverPathByEntity(type);
});
