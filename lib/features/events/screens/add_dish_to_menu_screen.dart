import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/section_header.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart';
import '../../catalog/data/dish_category.dart';
import '../../shopping/data/shopping_providers.dart';
import '../data/events_providers.dart';

/// Add dish to event menu (Specification 004 screen 5 / §3.7). Shows the
/// dish catalog grouped by category; tapping a dish copies it into the
/// event's menu via [EventsRepository.addDishToEvent]. Dishes already in the
/// menu are flagged, and re-adding one asks for confirmation before creating
/// a second independent copy.
class AddDishToMenuScreen extends ConsumerStatefulWidget {
  const AddDishToMenuScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AddDishToMenuScreen> createState() =>
      _AddDishToMenuScreenState();
}

class _AddDishToMenuScreenState extends ConsumerState<AddDishToMenuScreen> {
  bool _adding = false;

  Future<void> _add(Dish dish, {required bool alreadyInMenu}) async {
    if (_adding) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (alreadyInMenu) {
      final confirmed = await _confirmDuplicate(dish.name);
      if (confirmed != true) return;
    }

    setState(() => _adding = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .addDishToEvent(eventId: widget.eventId, dishId: dish.id);
      ref.invalidate(eventDishesProvider(widget.eventId));
      // Fixes §2.1/§2.3: keep the shopping panel in sync with the menu so the
      // re-added dish (with any catalog lines added since the first add) shows
      // up there without a restart.
      ref.invalidate(eventShoppingProvider(widget.eventId));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.addDishError)));
    }
  }

  Future<bool?> _confirmDuplicate(String name) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.addDuplicateDishConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.addDuplicateDishConfirmBody(name),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancelAction,
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.addDuplicateDishConfirmButton,
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
    final dishesAsync = ref.watch(dishesListProvider);
    final inMenuAsync = ref.watch(eventDishesProvider(widget.eventId));
    final inMenu = <String>{
      for (final d in inMenuAsync.value ?? const [])
        if (d.sourceDishId != null) d.sourceDishId!,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.addDishPickerTitle, style: AppTypography.sectionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: _adding ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            dishesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (_, _) => _LoadError(
                message: l10n.dishesLoadError,
                onRetry: () => ref.invalidate(dishesListProvider),
              ),
              data: (dishes) => dishes.isEmpty
                  ? const _EmptyState()
                  : _DishesByCategory(
                      dishes: dishes,
                      inMenu: inMenu,
                      onTap: (dish) => _add(
                        dish,
                        alreadyInMenu: inMenu.contains(dish.id),
                      ),
                    ),
            ),
            if (_adding)
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
}

class _DishesByCategory extends StatefulWidget {
  const _DishesByCategory({
    required this.dishes,
    required this.inMenu,
    required this.onTap,
  });

  final List<Dish> dishes;
  final Set<String> inMenu;
  final ValueChanged<Dish> onTap;

  @override
  State<_DishesByCategory> createState() => _DishesByCategoryState();
}

class _DishesByCategoryState extends State<_DishesByCategory> {
  late final Map<DishCategory, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final c in DishCategory.values) c: true};
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
              count: byCategory[category]!.length,
              expanded: _expanded[category]!,
              onToggle: () =>
                  setState(() => _expanded[category] = !_expanded[category]!),
            ),
            if (_expanded[category]!)
              for (final dish in byCategory[category]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DishRow(
                    dish: dish,
                    inMenu: widget.inMenu.contains(dish.id),
                    onTap: () => widget.onTap(dish),
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
    required this.inMenu,
    required this.onTap,
  });

  final Dish dish;
  final bool inMenu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              Expanded(
                child: Text(
                  dish.name,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (inMenu) ...[
                const SizedBox(width: 8),
                _InMenuBadge(label: l10n.dishAlreadyInMenuBadge),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.add, color: AppColors.accentSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _InMenuBadge extends StatelessWidget {
  const _InMenuBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentSecondarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accentSecondary,
          fontWeight: FontWeight.w500,
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
