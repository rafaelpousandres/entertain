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
import '../../shopping/supplier_category_format.dart';
import '../data/catalog_providers.dart';
import '../data/drink.dart';
import '../data/reference_data.dart';

/// Drinks catalog (Spec 014 §2.2). App-bar-less — hosted as the Begudes tab of
/// CatalogShell. Lists the group's drinks grouped by supplier category in an
/// accordion (consistent with the dish and ingredient catalogs), with an empty
/// state, a "New drink" action and tap-to-edit rows.
const String _uncategorisedKey = '__uncategorised__';

class BegudesCatalogScreen extends ConsumerStatefulWidget {
  const BegudesCatalogScreen({super.key});

  @override
  ConsumerState<BegudesCatalogScreen> createState() =>
      _BegudesCatalogScreenState();
}

class _BegudesCatalogScreenState extends ConsumerState<BegudesCatalogScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final drinksAsync = ref.watch(drinksListProvider);
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    final coverPaths =
        ref.watch(entityCoverPathsProvider(MediaEntityType.drink)).value ??
        const <String, String>{};

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: drinksAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.drinksLoadError,
            onRetry: () => ref.invalidate(drinksListProvider),
          ),
          data: (drinks) {
            if (drinks.isEmpty) return const _EmptyState();
            final categoriesById = {
              for (final c in categoriesAsync.value ?? const <SupplierCategory>[])
                c.id: c,
            };
            return _DrinksBySupplier(
              drinks: drinks,
              categoriesById: categoriesById,
              coverPaths: coverPaths,
              open: _open,
              onToggle: (key) =>
                  setState(() => _open = _open == key ? null : key),
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
          label: l10n.newDrinkAction,
          icon: Icons.add,
          onPressed: () => context.push('/drinks/new'),
        ),
      ),
    );
  }
}

class _DrinksBySupplier extends StatelessWidget {
  const _DrinksBySupplier({
    required this.drinks,
    required this.categoriesById,
    required this.coverPaths,
    required this.open,
    required this.onToggle,
  });

  final List<Drink> drinks;
  final Map<String, SupplierCategory> categoriesById;
  final Map<String, String> coverPaths;
  final String? open;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byKey = <String, List<Drink>>{};
    for (final drink in drinks) {
      byKey
          .putIfAbsent(drink.supplierCategoryId ?? _uncategorisedKey, () => [])
          .add(drink);
    }
    // Categories first (alphabetical), uncategorised last.
    final keys = byKey.keys.toList()
      ..sort((a, b) {
        if (a == _uncategorisedKey) return 1;
        if (b == _uncategorisedKey) return -1;
        final na = categoriesById[a]?.name ?? '';
        final nb = categoriesById[b]?.name ?? '';
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final key in keys) ...[
          () {
            final category = categoriesById[key];
            final isUncategorised = key == _uncategorisedKey;
            return SectionHeader(
              icon: isUncategorised
                  ? Icons.help_outline
                  : supplierCategoryIcon(category?.code ?? ''),
              label: isUncategorised
                  ? l10n.shoppingUncategorisedLabel
                  : (category?.name ?? l10n.shoppingUncategorisedLabel),
              countLabel: l10n.drinkCountLabel(byKey[key]!.length),
              expanded: open == key,
              onToggle: () => onToggle(key),
            );
          }(),
          if (open == key)
            for (final drink in byKey[key]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrinkRow(
                  drink: drink,
                  coverPath: coverPaths[drink.id],
                  onTap: () => context.push('/drinks/${drink.id}'),
                ),
              ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _DrinkRow extends StatelessWidget {
  const _DrinkRow({
    required this.drink,
    required this.coverPath,
    required this.onTap,
  });

  final Drink drink;
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
              if (coverPath != null) ...[
                RowPhotoThumb(
                  photoRef: (
                    bucket: PhotoStorage.drinkBucket,
                    path: coverPath!,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  drink.name,
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
                Icons.local_bar_outlined,
                color: AppColors.accentSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.drinksEmptyTitle,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.drinksEmptyBody,
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
