import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'media.dart';
import 'media_providers.dart';
import 'media_repository.dart';
import 'photo_storage.dart';

const _uuid = Uuid();

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
///
/// Spec 030 §B (create mode): when [creating] is true the entity row does not
/// exist yet, so photos cannot be written to its bucket or to `media` (both RLS
/// policies require the parent row). Instead they are uploaded to the staging
/// bucket and tracked in [pendingStaged]; on [commit] — after the editor has
/// inserted the entity row — each is PROMOTED to the real bucket and a `media`
/// row is inserted. On [rollback] the staged blobs are dropped. None of the
/// edit-mode snapshot/replay machinery runs in create mode.
class PhotoEditSession extends ChangeNotifier {
  PhotoEditSession({
    required this.type,
    required this.entityId,
    this.creating = false,
  });

  final MediaEntityType type;
  final String entityId;

  /// Whether the editor is CREATING the entity (its row does not exist yet), so
  /// photos go through the staging path rather than the entity bucket.
  final bool creating;

  /// Create-mode carousel: photos added before the entity exists, already
  /// uploaded to the staging bucket (path `{group_id}/{uuid}.jpg`). Synthetic
  /// [Media] (a local id + the staging path) so the carousel and full-screen
  /// viewer render and reorder them through the same code paths as real photos.
  final List<Media> pendingStaged = [];

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

  /// Create-mode: append a staged photo whose blob is already in the staging
  /// bucket at [stagedPath]. Provenance is carried for promoted stock photos
  /// (Spec 019 §C.2); null for camera/gallery.
  void addStaged(
    String stagedPath, {
    String? sourceProvider,
    String? sourceAuthor,
    String? sourceUrl,
    String? sourceRef,
  }) {
    pendingStaged.add(
      Media(
        id: _uuid.v4(),
        entityType: type,
        entityId: entityId,
        path: stagedPath,
        position: pendingStaged.length,
        sourceProvider: sourceProvider,
        sourceAuthor: sourceAuthor,
        sourceUrl: sourceUrl,
        sourceRef: sourceRef,
      ),
    );
    _dirty = true;
    notifyListeners();
  }

  /// Create-mode: drop a staged photo (and reindex the rest). The blob removal
  /// from the staging bucket is the caller's job (non-fatal; swept otherwise).
  void removeStaged(Media media) {
    pendingStaged.removeWhere((m) => m.id == media.id);
    _reindexStaged();
    _dirty = true;
    notifyListeners();
  }

  /// Create-mode: replace the staged order from a drag-reorder.
  void reorderStaged(List<Media> ordered) {
    pendingStaged
      ..clear()
      ..addAll(ordered);
    _reindexStaged();
    _dirty = true;
    notifyListeners();
  }

  void _reindexStaged() {
    for (var i = 0; i < pendingStaged.length; i++) {
      if (pendingStaged[i].position != i) {
        pendingStaged[i] = pendingStaged[i].copyWith(position: i);
      }
    }
  }

  /// On Save: the current state is confirmed. In create mode (Spec 030 §B) the
  /// entity row now exists (the editor inserted it just before calling this), so
  /// each staged photo is promoted to the entity bucket and a `media` row is
  /// inserted, in carousel order. A failure mid-list leaves the entity with
  /// fewer photos (the staged blob stays for the sweeper) — never the reverse,
  /// because the row was inserted first.
  Future<void> commit(WidgetRef ref) async {
    if (creating) {
      await _promoteStaged(ref);
      return;
    }
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

  Future<void> _promoteStaged(WidgetRef ref) async {
    await promoteStaged(
      ref.read(photoStorageProvider),
      ref.read(mediaRepositoryProvider),
    );
    ref.invalidate(entityMediaProvider((type: type, entityId: entityId)));
    ref.invalidate(entityCoverPathsProvider(type));
  }

  /// Testable core of create-mode promotion (Spec 030 §B): move each staged blob
  /// into the entity bucket, then insert its `media` row, in carousel order —
  /// move-then-insert per photo so a failure never leaves a `media` row with no
  /// blob. Entity-row-first ordering is the caller's responsibility (the editor
  /// inserts the entity row before [commit]).
  @visibleForTesting
  Future<void> promoteStaged(PhotoStorage storage, MediaRepository repo) async {
    if (pendingStaged.isEmpty) return;
    for (final m in pendingStaged) {
      final realPath = '$entityId/${_uuid.v4()}.jpg';
      await storage.promote(m.path, type.bucket, realPath);
      await repo.insert(
        type: type,
        entityId: entityId,
        path: realPath,
        position: m.position,
        sourceProvider: m.sourceProvider,
        sourceAuthor: m.sourceAuthor,
        sourceUrl: m.sourceUrl,
        sourceRef: m.sourceRef,
      );
    }
    pendingStaged.clear();
  }

  /// Testable core of create-mode discard (Spec 030 §B): drop every staged blob
  /// (best-effort; the sweeper catches leftovers) and clear the list.
  @visibleForTesting
  Future<void> discardStaged(PhotoStorage storage) async {
    if (pendingStaged.isEmpty) return;
    final paths = pendingStaged.map((m) => m.path).toList();
    pendingStaged.clear();
    try {
      await storage.remove(PhotoStorage.stagingBucket, paths);
    } catch (_) {
      // Non-fatal — the sweeper purges abandoned staged blobs.
    }
  }

  /// On Discard: restore the pre-edit state. In create mode (Spec 030 §B) there
  /// is no pre-edit state to restore — just drop the staged blobs (best-effort;
  /// the sweeper catches any that survive). In edit mode: remove photos added
  /// during the session (row + blob), re-insert originals that were deleted
  /// (their blobs were buffered, so they are still in Storage), restore the
  /// original order, and purge blobs that were added-then-deleted. May throw on
  /// a network error mid-replay — the caller surfaces the §2.6 non-fatal warning.
  Future<void> rollback(WidgetRef ref) async {
    final repo = ref.read(mediaRepositoryProvider);
    final storage = ref.read(photoStorageProvider);

    if (creating) {
      await discardStaged(storage);
      return;
    }

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
