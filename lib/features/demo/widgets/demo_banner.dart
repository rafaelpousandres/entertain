import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../events/data/events_providers.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_storage.dart';
import '../data/demo_prefs.dart';
import '../data/demo_providers.dart';

/// Spec 033 §A.5 — a dismissible banner on the events screen offering to clear
/// the onboarding example data. Hidden when there's no demo data left or the
/// user has dismissed it (so it occupies no space in either case).
class DemoBanner extends ConsumerStatefulWidget {
  const DemoBanner({super.key});

  @override
  ConsumerState<DemoBanner> createState() => _DemoBannerState();
}

class _DemoBannerState extends ConsumerState<DemoBanner> {
  bool _dismissed = true; // assume hidden until the pref loads
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    DemoPrefs.readDismissed().then((v) {
      if (mounted) setState(() => _dismissed = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final hasDemo = ref.watch(hasDemoDataProvider).value ?? false;
    if (!hasDemo) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.demoBannerTitle,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                InkWell(
                  onTap: _busy ? null : _dismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 8, top: 4),
              child: Text(
                l10n.demoBannerBody,
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : _confirmAndClear,
                  child: Text(
                    l10n.demoBannerAction,
                    style: AppTypography.button.copyWith(color: AppColors.accentSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss() async {
    await DemoPrefs.writeDismissed(true);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _confirmAndClear() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.demoClearConfirmTitle, style: AppTypography.sectionTitle),
        content: Text(
          l10n.demoClearConfirmBody,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(
              l10n.cancelAction,
              style: AppTypography.button.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              l10n.demoClearConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final purge = await ref.read(demoRepositoryProvider).clearDemoData();
      // Purge user-owned blobs the clear returned; the shared demo/ assets stay.
      final byBucket = <String, List<String>>{};
      for (final p in purge) {
        byBucket.putIfAbsent(p.bucket, () => []).add(p.path);
      }
      for (final entry in byBucket.entries) {
        try {
          await ref.read(photoStorageProvider).remove(entry.key, entry.value);
        } catch (_) {
          // Non-fatal: a leftover blob doesn't block clearing the data.
        }
      }
      // Refresh every surface the demo touched.
      ref.invalidate(hasDemoDataProvider);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventReadinessProvider);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(dishesListProvider);
      ref.invalidate(drinksListProvider);
      ref.invalidate(supplierCategoriesProvider);
      ref.invalidate(entityCoverPathsProvider);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.demoClearError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
