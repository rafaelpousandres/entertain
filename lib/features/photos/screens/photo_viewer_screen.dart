import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../data/photo_storage.dart';
import '../widgets/photo_remove_confirm.dart';

/// Full-screen viewer for a single photo (dish / ingredient — Spec 009
/// §2.2.5): pinch-to-zoom over a black backdrop, a back arrow, and a delete
/// action. Deletion is confirmed here but performed by the caller: the screen
/// pops with `true` when the user confirms removal, `null`/false otherwise.
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({super.key, required this.photoRef});

  final PhotoRef photoRef;

  /// Opens the viewer and resolves to true when the user asked to remove the
  /// photo (the caller then deletes the row/blob and refreshes).
  static Future<bool> open(BuildContext context, PhotoRef photoRef) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(photoRef: photoRef)),
    );
    return removed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bytesAsync = ref.watch(photoBytesProvider(photoRef));
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
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.photoRemovePhoto,
            onPressed: () async {
              final confirmed = await showPhotoRemoveConfirm(context);
              if (confirmed && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
      body: bytesAsync.when(
        data: (bytes) => PhotoView(
          imageProvider: MemoryImage(bytes),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, _) => Center(
          child: Text(
            l10n.photoLoadError,
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
