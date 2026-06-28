import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_edit_session.dart';
import '../data/stock_photo.dart';
import '../data/stock_photo_providers.dart';
import '../data/stock_photo_repository.dart';

/// Route arguments for [StockPhotoSearchScreen] (passed as go_router `extra`).
class StockPhotoSearchArgs {
  const StockPhotoSearchArgs({
    required this.type,
    required this.entityId,
    required this.locale,
    this.initialQuery,
    this.creating = false,
    this.groupId,
  });

  final MediaEntityType type;
  final String entityId;

  /// Pexels locale, e.g. `ca-ES` / `es-ES` / `en-US`.
  final String locale;

  /// Spec 021 §B6: prefill the search field with the entity's name so the
  /// user doesn't retype it. Local language for now; the English bridge waits
  /// on multilingual ingredient names. Null leaves the field empty.
  final String? initialQuery;

  /// Spec 030 §B: true when adding a photo while CREATING the entity — the
  /// function stages the photo by [groupId] (the entity row does not exist yet)
  /// and the result is added to the session's staged list instead of `media`.
  final bool creating;

  /// The caller's group id, required in create mode for the staging path.
  final String? groupId;
}

/// Spec 019 §C.1 — stock-photo search. A search field, a results grid (each
/// result credits its photographer), and a header showing the remaining monthly
/// quota. Tapping a result copies it onto the entity via the Edge Function and
/// returns to the editor; a reached limit shows the paywall-seam message.
class StockPhotoSearchScreen extends ConsumerStatefulWidget {
  const StockPhotoSearchScreen({super.key, required this.args});

  final StockPhotoSearchArgs args;

  @override
  ConsumerState<StockPhotoSearchScreen> createState() =>
      _StockPhotoSearchScreenState();
}

class _StockPhotoSearchScreenState
    extends ConsumerState<StockPhotoSearchScreen> {
  final _controller = TextEditingController();
  AsyncValue<List<StockPhoto>>? _results;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Spec 021 §B6: prefill with the entity name; the user can edit or run it
    // as-is. We don't auto-search — the user taps search when ready.
    _controller.text = widget.args.initialQuery?.trim() ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _results = const AsyncValue.loading());
    try {
      final photos = await ref
          .read(stockPhotoRepositoryProvider)
          .search(query: query, locale: widget.args.locale);
      if (mounted) setState(() => _results = AsyncValue.data(photos));
    } catch (e, st) {
      if (mounted) setState(() => _results = AsyncValue.error(e, st));
    }
  }

  Future<void> _pick(StockPhoto photo) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(stockPhotoRepositoryProvider)
          .save(
            photo: photo,
            type: widget.args.type,
            entityId: widget.args.entityId,
            staging: widget.args.creating,
            groupId: widget.args.groupId,
          );
      if (!mounted) return;
      final session = ref
          .read(photoEditRegistryProvider)
          .lookup(widget.args.type, widget.args.entityId);
      if (widget.args.creating && result.stagedPath != null) {
        // Spec 030 §B: the entity does not exist yet — add the staged photo to
        // the editor's session, carrying Pexels provenance for promotion.
        session?.addStaged(
          result.stagedPath!,
          sourceProvider: 'pexels',
          sourceAuthor: photo.photographer,
          sourceUrl: photo.pageUrl,
          sourceRef: photo.id,
        );
      } else {
        // Refresh the carousel, list/menu cover thumbnails.
        ref.invalidate(
          entityMediaProvider((
            type: widget.args.type,
            entityId: widget.args.entityId,
          )),
        );
        ref.invalidate(entityCoverPathsProvider(widget.args.type));
        // §2.6 parity with camera/gallery: a new photo is an unsaved change the
        // editor can roll back on Discard.
        session?.markDirty();
      }
      ref.invalidate(stockPhotoQuotaProvider);
      context.pop();
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showLimitReached(e.limit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaveError)));
    }
  }

  void _showLimitReached(int limit) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.stockLimitReachedTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.stockLimitReachedBody(limit),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.okAction,
              style: AppTypography.button.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quota = ref.watch(stockPhotoQuotaProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.stockSearchTitle, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: l10n.stockSearchHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        color: AppColors.accentSecondary,
                        tooltip: l10n.stockSearchAction,
                        onPressed: _search,
                      ),
                    ),
                  ),
                ),
                // Live remaining-quota header.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      quota.when(
                        data: (q) =>
                            l10n.stockRemainingLabel(q.remaining, q.limit),
                        loading: () => '',
                        error: (_, _) => '',
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildResults(l10n)),
              ],
            ),
            if (_saving)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    final results = _results;
    if (results == null) {
      return _CenteredHint(text: l10n.stockSearchEmptyPrompt);
    }
    return results.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, _) => _CenteredHint(text: l10n.stockSearchError),
      data: (photos) {
        if (photos.isEmpty) {
          return _CenteredHint(text: l10n.stockSearchNoResults);
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) =>
              _ResultTile(photo: photos[i], onTap: () => _pick(photos[i])),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.photo, required this.onTap});

  final StockPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.surface,
                width: double.infinity,
                child: Image.network(
                  photo.previewUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                  errorBuilder: (context, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.disabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // §C.1: per-photo attribution, satisfied at point of selection.
          Text(
            l10n.stockPhotoCredit(photo.photographer),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
