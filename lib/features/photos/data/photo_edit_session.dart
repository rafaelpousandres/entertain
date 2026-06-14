import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media.dart';
import 'media_providers.dart';
import 'photo_storage.dart';

/// Spec 011 §2.6 — approximate (application-layer) rollback of photo edits.
///
/// Photos are persisted to Supabase Storage immediately on pick (the multi-photo
/// flow makes deferring all persistence — Option C — a large refactor), so a
/// plain "Discard" on the dish/ingredient editor would leave photo changes
/// behind while reverting every other field. Option B closes that gap: the
/// editor opens a session that snapshots the entity's photos and tracks the
/// changes made during editing, then on Discard replays them in reverse.
///
/// The one behaviour change to the immediate flow is that a delete during a
/// session **keeps its blob in Storage** (it is only buffered in
/// [deferredBlobs]) until the editor commits — so a deleted or replaced photo
/// can be restored on Discard. On Save the buffered blobs are purged.
///
/// Scope: best-effort, not transactional. A mid-edit app crash leaves partial
/// changes (acceptable); a network error during the reverse replay surfaces a
/// non-fatal warning and leaves the user to resolve it manually.
class PhotoEditSession extends ChangeNotifier {
  PhotoEditSession({required this.type, required this.entityId});

  final MediaEntityType type;
  final String entityId;

  /// The photos as they were when the editor opened, in carousel order. The
  /// baseline that [rollback] restores to.
  List<Media> _original = const [];
  bool _snapshotted = false;

  /// Blob paths whose `media` row was deleted during the session but whose blob
  /// was intentionally left in Storage, so a Discard can restore the row.
  final Set<String> deferredBlobs = {};

  bool _dirty = false;

  /// Whether any photo change happened during the session (drives the editor's
  /// unsaved-changes guard, per Spec 009 Fixes / Spec 011 §2.6).
  bool get dirty => _dirty;

  /// Records the pre-edit baseline. Called once, as early as possible.
  void snapshot(List<Media> original) {
    if (_snapshotted) return;
    _original = List.of(original);
    _snapshotted = true;
  }

  /// Flags the session dirty (and notifies the editor to rebuild its guard).
  void markDirty() {
    if (_dirty) return;
    _dirty = true;
    notifyListeners();
  }

  /// On Save: the current state is confirmed, so purge every buffered blob the
  /// final state no longer references (deleted or replaced originals, and any
  /// add-then-delete leftovers). Non-fatal: orphans are swept later.
  Future<void> commit(WidgetRef ref) async {
    if (deferredBlobs.isEmpty) return;
    final repo = ref.read(mediaRepositoryProvider);
    final storage = ref.read(photoStorageProvider);
    final current = await repo.listForEntity(type, entityId);
    final keep = current.map((m) => m.path).toSet();
    final toPurge = [
      for (final path in deferredBlobs)
        if (!keep.contains(path)) path,
    ];
    if (toPurge.isEmpty) return;
    try {
      await storage.remove(type.bucket, toPurge);
    } catch (_) {
      // Non-fatal — orphan blobs are swept later.
    }
  }

  /// On Discard: restore the pre-edit state. Removes photos added during the
  /// session (row + blob), re-inserts originals that were deleted (their blobs
  /// were buffered, so they are still in Storage), restores the original order,
  /// and purges blobs that were added-then-deleted. May throw on a network
  /// error mid-replay — the caller surfaces the §2.6 non-fatal warning.
  Future<void> rollback(WidgetRef ref) async {
    final repo = ref.read(mediaRepositoryProvider);
    final storage = ref.read(photoStorageProvider);
    final current = await repo.listForEntity(type, entityId);
    final originalPaths = _original.map((m) => m.path).toSet();
    final currentPaths = current.map((m) => m.path).toSet();

    // 1. Delete photos added during the session (row + blob).
    for (final m in current) {
      if (!originalPaths.contains(m.path)) {
        await repo.deleteById(m.id);
        try {
          await storage.remove(type.bucket, [m.path]);
        } catch (_) {}
      }
    }

    // 2. Re-insert originals deleted during the session; the blob is still in
    //    Storage (it was buffered, not removed), so the row alone restores it.
    for (final m in _original) {
      if (!currentPaths.contains(m.path)) {
        await repo.insert(
          type: type,
          entityId: entityId,
          path: m.path,
          position: m.position,
        );
      }
    }

    // 3. Restore the original order (re-inserted rows have new ids, so reorder
    //    by matching the original path sequence to the live rows).
    final restored = await repo.listForEntity(type, entityId);
    final byPath = {for (final m in restored) m.path: m};
    final ordered = [
      for (final m in _original)
        if (byPath[m.path] != null) byPath[m.path]!,
    ];
    if (ordered.isNotEmpty) {
      await repo.reorder(ordered);
    }

    // 4. Purge blobs added-then-deleted within the session (buffered, never part
    //    of the original, and not restored).
    final restoredPaths = restored.map((m) => m.path).toSet();
    for (final path in deferredBlobs) {
      if (!originalPaths.contains(path) && !restoredPaths.contains(path)) {
        try {
          await storage.remove(type.bucket, [path]);
        } catch (_) {}
      }
    }

    ref.invalidate(entityMediaProvider((type: type, entityId: entityId)));
    ref.invalidate(entityCoverPathsProvider(type));
  }
}

/// Process-wide registry of the active [PhotoEditSession]s, keyed by entity, so
/// the global photo actions (which run from the inline carousel and the
/// full-screen viewer route alike) can find the session for the entity they
/// touch without threading it through every widget. At most one editor edits a
/// given entity at a time.
class PhotoEditRegistry {
  final Map<String, PhotoEditSession> _byKey = {};

  String _key(MediaEntityType type, String entityId) =>
      '${type.wire}:$entityId';

  PhotoEditSession? lookup(MediaEntityType type, String entityId) =>
      _byKey[_key(type, entityId)];

  void register(PhotoEditSession session) {
    _byKey[_key(session.type, session.entityId)] = session;
  }

  void unregister(PhotoEditSession session) {
    final key = _key(session.type, session.entityId);
    if (_byKey[key] == session) _byKey.remove(key);
  }
}

final photoEditRegistryProvider = Provider<PhotoEditRegistry>(
  (ref) => PhotoEditRegistry(),
);
