import 'package:supabase_flutter/supabase_flutter.dart';

import 'media.dart';

/// Data-access for the polymorphic `media` table (Specification 010 §2.4).
///
/// Reads and writes photo rows for any of the three entity types behind the
/// `(entity_type, entity_id)` key. RLS scopes every row to the caller's group
/// through the owning entity, so no group filter is needed here.
class MediaRepository {
  MediaRepository(this._client);

  final SupabaseClient _client;

  /// An entity's photos in carousel order: ascending `position`, then ascending
  /// `created_at` as the tiebreaker (Spec 009 §2.2.6, carried over).
  Future<List<Media>> listForEntity(
    MediaEntityType type,
    String entityId,
  ) async {
    final rows = await _client
        .from('media')
        .select(Media.selectColumns)
        .eq('entity_type', type.wire)
        .eq('entity_id', entityId)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Media.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// The cover photo (first by carousel order) of every entity of [type] the
  /// caller can see, as a map of entity id → object path. Used by the list /
  /// menu surfaces to show a thumbnail without an N+1. RLS already scopes the
  /// rows to the user's groups, so no explicit group filter is required; the
  /// first row seen per entity is its lowest `position` (ties broken by
  /// `created_at`), later rows ignored.
  Future<Map<String, String>> coverPathByEntity(MediaEntityType type) async {
    final rows = await _client
        .from('media')
        .select('entity_id, path')
        .eq('entity_type', type.wire)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    final result = <String, String>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      result.putIfAbsent(row['entity_id'] as String, () => row['path'] as String);
    }
    return result;
  }

  /// Inserts a media row after its blob has been uploaded. [position] is
  /// typically the current photo count, so the new photo lands at the end.
  Future<void> insert({
    required MediaEntityType type,
    required String entityId,
    required String path,
    required int position,
  }) async {
    await _client.from('media').insert({
      'entity_type': type.wire,
      'entity_id': entityId,
      'path': path,
      'position': position,
    });
  }

  /// Removes a single media row (the blob is removed by the caller).
  Future<void> deleteById(String id) async {
    await _client.from('media').delete().eq('id', id);
  }

  /// Removes every media row of an entity and returns the object paths that
  /// were referenced, so the caller can purge the blobs. Used on the *soft*
  /// delete of an entity, where the cleanup trigger never fires (Spec 010 §2.4).
  Future<List<String>> deleteForEntity(
    MediaEntityType type,
    String entityId,
  ) async {
    final rows = await _client
        .from('media')
        .delete()
        .eq('entity_type', type.wire)
        .eq('entity_id', entityId)
        .select('path');
    return [for (final r in rows as List) (r as Map<String, dynamic>)['path'] as String];
  }

  /// Persists a new carousel order (Spec 009 §6.1): each row's `position` is
  /// rewritten to its index in [ordered] in one upsert keyed on the primary key.
  /// `entity_type` / `entity_id` / `path` are carried so the NOT NULL columns
  /// are satisfied on the update path.
  Future<void> reorder(List<Media> ordered) async {
    if (ordered.isEmpty) return;
    final payload = [
      for (var i = 0; i < ordered.length; i++)
        {
          'id': ordered[i].id,
          'entity_type': ordered[i].entityType.wire,
          'entity_id': ordered[i].entityId,
          'path': ordered[i].path,
          'position': i,
        },
    ];
    await _client.from('media').upsert(payload);
  }
}
