import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/help_icon_button.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/section_header.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_storage.dart';
import '../../photos/widgets/photo_image.dart';
import '../data/dish.dart';
import '../data/dish_category.dart';
import '../data/catalog_providers.dart';

/// Dish catalog (Specification 004 screen 1). Lists the group's dishes
/// grouped by category with collapsible section headers, an empty state, a
/// "New dish" primary action and tap-to-edit rows.
class DishCatalogScreen extends ConsumerWidget {
  const DishCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dishesAsync = ref.watch(dishesListProvider);
    // Spec 010 §2.4: row thumbnails read the cover (first photo by position)
    // from the polymorphic media table.
    final coverPaths =
        ref.watch(entityCoverPathsProvider(MediaEntityType.dish)).value ??
        const <String, String>{};

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.dishesScreenTitle, style: AppTypography.display),
        actions: [
          // Spec 012 §2.4: per-screen help pop-up.
          HelpIconButton(
            title: l10n.dishesScreenTitle,
            body: l10n.helpDishesBody,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dishesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.dishesLoadError,
            onRetry: () => ref.invalidate(dishesListProvider),
          ),
          data: (dishes) => dishes.isEmpty
              ? const _EmptyState()
              : _DishesByCategory(dishes: dishes, coverPaths: coverPaths),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: l10n.newDishAction,
          icon: Icons.add,
          onPressed: () => context.push('/dishes/new'),
        ),
      ),
    );
  }
}

class _DishesByCategory extends StatefulWidget {
  const _DishesByCategory({required this.dishes, required this.coverPaths});

  final List<Dish> dishes;

  /// Dish id → cover photo path (first by position), or absent when none.
  final Map<String, String> coverPaths;

  @override
  State<_DishesByCategory> createState() => _DishesByCategoryState();
}

class _DishesByCategoryState extends State<_DishesByCategory> {
  // Spec 012 §2.7: accordion — all categories collapsed by default, at most one
  // open at a time (consistent with the shopping panel, Spec 011 §2.8).
  DishCategory? _open;

  void _toggle(DishCategory category) {
    setState(() => _open = _open == category ? null : category);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byCategory = <DishCategory, List<Dish>>{};
    for (final dish in widget.dishes) {
      byCategory.putIfAbsent(dish.category, () => []).add(dish);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final category in dishCategoryOrder)
          if (byCategory[category] != null) ...[
            SectionHeader(
              icon: dishCategoryIcon(category),
              label: dishCategoryLabel(l10n, category),
              // §2.7: count now carries the "plats" word.
              countLabel: l10n.dishCountLabel(byCategory[category]!.length),
              expanded: _open == category,
              onToggle: () => _toggle(category),
            ),
            if (_open == category)
              for (final dish in byCategory[category]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DishRow(
                    dish: dish,
                    coverPath: widget.coverPaths[dish.id],
                    onTap: () => context.push('/dishes/${dish.id}'),
                  ),
                ),
            const SizedBox(height: 4),
          ],
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.coverPath, required this.onTap});

  final Dish dish;
  final String? coverPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Spec 010 §2.4: inline cover thumbnail when the dish has a photo.
              if (coverPath != null) ...[
                RowPhotoThumb(
                  photoRef: (
                    bucket: PhotoStorage.dishBucket,
                    path: coverPath!,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  dish.name,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentSecondarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                color: AppColors.accentSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dishesEmptyTitle,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.dishesEmptyBody,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.retryAction,
                style: AppTypography.button.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
