import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/section_header.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_storage.dart';
import '../../photos/widgets/photo_image.dart';
import '../data/dish.dart';
import '../data/dish_category.dart';
import '../data/diet.dart';
import '../widgets/dietary_badges.dart';
import '../data/catalog_providers.dart';

/// Dish catalog (Specification 004 screen 1). Lists the group's dishes
/// grouped by category with collapsible section headers, an empty state, a
/// "New dish" primary action and tap-to-edit rows.
///
/// The open accordion category is held here (not inside the list widget) so
/// the "New dish" button can preselect it in the editor (§A): a brand-new dish
/// defaults to the open category, or the first category when all collapsed.
class DishCatalogScreen extends ConsumerStatefulWidget {
  const DishCatalogScreen({super.key});

  @override
  ConsumerState<DishCatalogScreen> createState() => _DishCatalogScreenState();
}

class _DishCatalogScreenState extends ConsumerState<DishCatalogScreen> {
  // §2.7 accordion — all categories collapsed by default, at most one open at a
  // time. Null means all collapsed.
  DishCategory? _open;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dishesAsync = ref.watch(dishesListProvider);
    // Spec 010 §2.4: row thumbnails read the cover (first photo by position)
    // from the polymorphic media table.
    final coverPaths =
        ref.watch(entityCoverPathsProvider(MediaEntityType.dish)).value ??
        const <String, String>{};

    // Spec 014: this catalog now lives as a tab inside CatalogShell, which
    // owns the AppBar (title + help) and the TabBar; the screen is app-bar-less
    // and keeps its own "New dish" bottom action (the open-category preselect
    // logic lives here).
    return Scaffold(
      backgroundColor: AppColors.bg,
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
          data: (dishes) {
            if (dishes.isEmpty) return const _EmptyState();
            // Spec 025 Part C: effective dietary per dish (derived for cooked
            // dishes with ingredients, else manual) drives the filter + badges.
            final dietMap = ref.watch(dishDietMapProvider).value ??
                const <String, ({DietLevel diet, TriState gf})>{};
            final filter = ref.watch(catalogFilterProvider);
            final filtered = dishes.where((d) {
              final eff = effectiveDishDietOf(d, dietMap);
              return dishMatchesDietary(eff.diet, eff.gf, filter.diet) &&
                  dishMatchesAcquisition(d.acquisitionMode, filter.acquisition);
            }).toList();
            return Column(
              children: [
                _buildFilterBar(l10n, filter),
                Expanded(
                  child: filtered.isEmpty
                      ? _NoMatch(message: l10n.catalogNoMatch)
                      : _DishesByCategory(
                          dishes: filtered,
                          coverPaths: coverPaths,
                          dietMap: dietMap,
                          open: _open,
                          onToggle: (category) => setState(
                            () => _open = _open == category ? null : category,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spec 020 §7: AI dish assistant — a first-class action harmonized
            // with "New dish" (same height/shape), distinguished by an accent
            // outline + the AI symbol (present on every AI-driven action).
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/ai-dish-assistant'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: AppColors.accent,
                ),
                label: Text(
                  l10n.dishAssistantCreateAction,
                  style: AppTypography.button.copyWith(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: l10n.newDishAction,
              icon: Icons.add,
              // §A: preselect the open accordion category (or the first
              // category when all collapsed) as an editable default.
              onPressed: () => context.push(
                '/dishes/new',
                extra: _open ?? dishCategoryActive.first,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n, CatalogFilter filter) {
    final notifier = ref.read(catalogFilterProvider.notifier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in DietChip.values)
            _FilterChip(
              label: dietChipLabel(l10n, c),
              selected: filter.diet.contains(c),
              onTap: () => notifier.toggleDiet(c),
            ),
          _FilterChip(
            label: l10n.filterCooked,
            selected: filter.acquisition == DishAcquisitionMode.cooked,
            onTap: () => notifier.toggleAcquisition(DishAcquisitionMode.cooked),
          ),
          _FilterChip(
            label: l10n.filterBought,
            selected: filter.acquisition == DishAcquisitionMode.bought,
            onTap: () => notifier.toggleAcquisition(DishAcquisitionMode.bought),
          ),
        ],
      ),
    );
  }
}

/// A compact toggle chip for the catalog filter bar (Spec 025 Part C).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accentSecondarySoft : AppColors.surface;
    final fg = selected ? AppColors.accentSecondary : AppColors.textPrimary;
    final border = selected ? AppColors.accentSecondary : AppColors.border;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral state when an active filter matches no dishes (Spec 025 Part C).
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// A dish's effective dietary status: derived (cooked + has ingredients) or the
/// manual fields (bought, or cooked with no lines). Spec 025 B.4.
({DietLevel diet, TriState gf}) effectiveDishDietOf(
  Dish d,
  Map<String, ({DietLevel diet, TriState gf})> dietMap,
) {
  final e = dietMap[d.id];
  if (!d.isBought && e != null) return e;
  return (diet: d.diet, gf: d.glutenFree);
}

class _DishesByCategory extends StatelessWidget {
  const _DishesByCategory({
    required this.dishes,
    required this.coverPaths,
    required this.dietMap,
    required this.open,
    required this.onToggle,
  });

  final List<Dish> dishes;

  /// Dish id → cover photo path (first by position), or absent when none.
  final Map<String, String> coverPaths;

  /// Dish id → derived dietary status (for dishes with ingredients).
  final Map<String, ({DietLevel diet, TriState gf})> dietMap;

  /// The currently open accordion category, owned by the parent so the "New
  /// dish" action can preselect it. Null when all sections are collapsed.
  final DishCategory? open;
  final ValueChanged<DishCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byCategory = <DishCategory, List<Dish>>{};
    for (final dish in dishes) {
      byCategory.putIfAbsent(dish.category, () => []).add(dish);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final category in dishCategoryActive)
          if (byCategory[category] != null) ...[
            SectionHeader(
              icon: dishCategoryIcon(category),
              label: dishCategoryLabel(l10n, category),
              // §2.7: count now carries the "plats" word.
              countLabel: l10n.dishCountLabel(byCategory[category]!.length),
              expanded: open == category,
              onToggle: () => onToggle(category),
            ),
            if (open == category)
              for (final dish in byCategory[category]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DishRow(
                    dish: dish,
                    coverPath: coverPaths[dish.id],
                    effective: effectiveDishDietOf(dish, dietMap),
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
  const _DishRow({
    required this.dish,
    required this.coverPath,
    required this.effective,
    required this.onTap,
  });

  final Dish dish;
  final String? coverPath;
  final ({DietLevel diet, TriState gf}) effective;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBadges =
        dietaryBadgesFor(effective.diet, effective.gf).isNotEmpty;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dish.name,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasBadges)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: DietaryBadges(
                          diet: effective.diet,
                          glutenFree: effective.gf,
                        ),
                      ),
                  ],
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
