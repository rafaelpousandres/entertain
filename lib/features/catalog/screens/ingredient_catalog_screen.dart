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
import '../../shopping/supplier_category_format.dart';
import '../data/catalog_providers.dart';
import '../data/ingredient.dart';
import '../data/reference_data.dart';

/// Ingredient catalog (Specification 004 screen 4). Lists the group's
/// ingredients with their default unit and supplier category, with an empty
/// state, a "New ingredient" primary action and tap-to-edit rows.
class IngredientCatalogScreen extends ConsumerWidget {
  const IngredientCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final unitsAsync = ref.watch(unitsProvider(localeCode));
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    // Spec 010 §2.4: row thumbnails read the cover (first photo by position)
    // from the polymorphic media table.
    final coverPaths =
        ref.watch(entityCoverPathsProvider(MediaEntityType.ingredient)).value ??
        const <String, String>{};

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.ingredientsScreenTitle, style: AppTypography.display),
        actions: [
          // Spec 012 §2.4: per-screen help pop-up.
          HelpIconButton(
            title: l10n.ingredientsScreenTitle,
            body: l10n.helpIngredientsBody,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ingredientsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.ingredientsLoadError,
            onRetry: () => ref.invalidate(ingredientsListProvider),
          ),
          data: (ingredients) {
            if (ingredients.isEmpty) {
              return const _EmptyState();
            }
            final units = unitsAsync.value ?? const <Unit>[];
            final categories =
                categoriesAsync.value ?? const <SupplierCategory>[];
            final unitsById = {for (final u in units) u.id: u};
            final categoriesById = {for (final c in categories) c.id: c};

            // Spec 012 §2.8: group by supplier category in an accordion instead
            // of a flat list.
            return _IngredientsBySupplier(
              ingredients: ingredients,
              unitsById: unitsById,
              categoriesById: categoriesById,
              coverPaths: coverPaths,
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
        child: PrimaryButton(
          label: l10n.newIngredientAction,
          icon: Icons.add,
          onPressed: () => context.push('/ingredients/new'),
        ),
      ),
    );
  }
}

/// Spec 012 §2.8 — ingredients grouped by supplier category in an accordion
/// (all collapsed by default, one open at a time), mirroring the dish catalog
/// and the shopping panel. Dispatch-capable suppliers come first sorted by
/// name, then the consultive pantry, then any uncategorised ingredients.
class _IngredientsBySupplier extends StatefulWidget {
  const _IngredientsBySupplier({
    required this.ingredients,
    required this.unitsById,
    required this.categoriesById,
    required this.coverPaths,
  });

  /// Ingredients pre-sorted by name (from `ingredientsListProvider`); the
  /// within-group order is preserved from this list.
  final List<Ingredient> ingredients;
  final Map<String, Unit> unitsById;
  final Map<String, SupplierCategory> categoriesById;
  final Map<String, String> coverPaths;

  @override
  State<_IngredientsBySupplier> createState() => _IngredientsBySupplierState();
}

class _IngredientsBySupplierState extends State<_IngredientsBySupplier> {
  /// Group key currently open, or null when all are collapsed. The
  /// uncategorised group uses [_uncategorisedKey].
  String? _open;

  static const String _uncategorisedKey = '__uncategorised__';

  void _toggle(String key) {
    setState(() => _open = _open == key ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Group ingredients by their default supplier category (null → pantry-less
    // "Uncategorised" bucket). Insertion order keeps the name sort within each
    // group.
    final byKey = <String, List<Ingredient>>{};
    for (final ingredient in widget.ingredients) {
      final key = ingredient.defaultSupplierCategoryId ?? _uncategorisedKey;
      byKey.putIfAbsent(key, () => []).add(ingredient);
    }

    // Order the group headers: dispatch suppliers first (alphabetical), then
    // pantry, then uncategorised last — consistent with the Suppliers settings
    // tab and the shopping panel.
    final keys = byKey.keys.toList()
      ..sort((a, b) {
        if (a == _uncategorisedKey) return 1;
        if (b == _uncategorisedKey) return -1;
        final ca = widget.categoriesById[a];
        final cb = widget.categoriesById[b];
        final aPantry = ca != null && isPantryCategory(ca.code);
        final bPantry = cb != null && isPantryCategory(cb.code);
        if (aPantry != bPantry) return aPantry ? 1 : -1;
        final na = ca?.name ?? '';
        final nb = cb?.name ?? '';
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final key in keys) ...[
          () {
            final category = widget.categoriesById[key];
            final isUncategorised = key == _uncategorisedKey;
            return SectionHeader(
              icon: isUncategorised
                  ? Icons.help_outline
                  : supplierCategoryIcon(category?.code ?? ''),
              label: isUncategorised
                  ? l10n.shoppingUncategorisedLabel
                  : (category?.name ?? l10n.shoppingUncategorisedLabel),
              countLabel: l10n.ingredientCountLabel(byKey[key]!.length),
              expanded: _open == key,
              onToggle: () => _toggle(key),
            );
          }(),
          if (_open == key)
            for (final ingredient in byKey[key]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IngredientRow(
                  ingredient: ingredient,
                  coverPath: widget.coverPaths[ingredient.id],
                  unit: widget.unitsById[ingredient.defaultUnitId],
                  // §2.8: the supplier is now the group header, so the row
                  // subtitle shows only the unit (no redundant category).
                  category: null,
                  onTap: () => context.push('/ingredients/${ingredient.id}'),
                ),
              ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.coverPath,
    required this.unit,
    required this.category,
    required this.onTap,
  });

  final Ingredient ingredient;
  final String? coverPath;
  final Unit? unit;
  final SupplierCategory? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[
      if (unit != null) unit!.name,
      if (category != null) category!.name,
    ];
    final subtitle = parts.join(l10n.metadataSeparator);

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
              // Spec 010 §2.4: inline cover thumbnail when the ingredient has a
              // photo.
              if (coverPath != null) ...[
                RowPhotoThumb(
                  photoRef: (
                    bucket: PhotoStorage.ingredientBucket,
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
                      ingredient.name,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                Icons.eco_outlined,
                color: AppColors.accentSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.ingredientsEmptyTitle,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ingredientsEmptyBody,
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
