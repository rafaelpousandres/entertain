import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media.dart';
import 'media_providers.dart';
import 'photo_edit_session.dart';

/// Spec 011 §2.6 — drop-in photo rollback for an editor [ConsumerState].
///
/// The host editor calls [initPhotoSession] once (when the entity already
/// exists, i.e. editing), reads [photosDirty] into its unsaved-changes guard,
/// and calls [commitPhotoSession] on Save / [rollbackPhotoSession] on Discard.
/// Session cleanup is handled in [dispose] (which chains to the editor's own
/// dispose via `super`).
mixin PhotoEditSessionHost<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  PhotoEditSession? _photoSession;
  PhotoEditRegistry? _photoRegistry;

  /// Opens a session for [type]/[entityId] and snapshots its current photos as
  /// the rollback baseline. Call once from `initState`. Pass [creating] true on
  /// a create screen (Spec 030 §B): the entity row does not exist yet, so the
  /// session tracks staged photos and skips the edit-mode snapshot.
  void initPhotoSession(
    MediaEntityType type,
    String entityId, {
    bool creating = false,
  }) {
    final session = PhotoEditSession(
      type: type,
      entityId: entityId,
      creating: creating,
    );
    final registry = ref.read(photoEditRegistryProvider);
    _photoSession = session;
    _photoRegistry = registry;
    registry.register(session);
    session.addListener(_onPhotoSessionChanged);

    // Create mode has no pre-edit photos to snapshot — the staged list is the
    // whole state.
    if (creating) return;

    final target = (type: type, entityId: entityId);
    final existing = ref.read(entityMediaProvider(target)).value;
    if (existing != null) {
      session.snapshot(existing);
    } else {
      ref.read(entityMediaProvider(target).future).then((media) {
        if (mounted) session.snapshot(media);
      });
    }
  }

  void _onPhotoSessionChanged() {
    if (mounted) setState(() {});
  }

  /// Whether photos changed during the session (feeds the editor's guard).
  bool get photosDirty => _photoSession?.dirty ?? false;

  /// Confirms the photo changes on Save: purges the buffered blobs.
  Future<void> commitPhotoSession() async {
    await _photoSession?.commit(ref);
  }

  /// Reverts the photo changes on Discard. Returns false if the rollback failed
  /// partway, so the caller can warn the user and keep them in the editor.
  Future<bool> rollbackPhotoSession() async {
    final session = _photoSession;
    if (session == null) return true;
    try {
      await session.rollback(ref);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    final session = _photoSession;
    if (session != null) {
      session.removeListener(_onPhotoSessionChanged);
      _photoRegistry?.unregister(session);
      session.dispose();
    }
    super.dispose();
  }
}
