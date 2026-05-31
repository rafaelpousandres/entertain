import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart' show formatQuantity;
import '../../catalog/data/dish_category.dart';
import '../../catalog/data/reference_data.dart';
import '../data/event_dish_line.dart';
import '../data/events_providers.dart';
import 'event_dish_line_editor_screen.dart';

/// Per-event dish detail (Specification 004 §3.8). Shows the snapshot fields
/// of an `event_dishes` row and its editable `event_dish_ingredients` lines.
/// Each line opens the per-event line editor; the overflow removes the whole
/// dish from the menu (physical delete of the per-event rows).
class EventDishDetailScreen extends ConsumerWidget {
  const EventDishDetailScreen({
    super.key,
    required this.eventId,
    required this.eventDishId,
  });

  final String eventId;
  final String eventDishId;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.removeDishConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.removeDishConfirmBody,
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
              l10n.removeDishConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(eventsRepositoryProvider).removeEventDish(eventDishId);
      ref.invalidate(eventDishesProvider(eventId));
      if (!context.mounted) return;
      context.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventDishSaveError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final dishAsync = ref.watch(eventDishByIdProvider(eventDishId));
    final linesAsync = ref.watch(eventDishLinesProvider(eventDishId));
    final units = ref.watch(unitsProvider(localeCode)).value;
    final categories = ref.watch(supplierCategoriesProvider(localeCode)).value;

    final unitsById = {for (final u in units ?? const <Unit>[]) u.id: u};
    final categoriesById = {
      for (final c in categories ?? const <SupplierCategory>[]) c.id: c,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          dishAsync.value?.name ?? '',
          style: AppTypography.sectionTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<_OverflowAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreActionsLabel,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (action) {
              switch (action) {
                case _OverflowAction.remove:
                  _confirmRemove(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _OverflowAction.remove,
                child: Text(
                  l10n.removeDishFromMenuAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dishAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.eventsLoadError,
            onRetry: () => ref.invalidate(eventDishByIdProvider(eventDishId)),
          ),
          data: (dish) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                '${dishCategoryLabel(l10n, dish.category)}'
                '${l10n.metadataSeparator}'
                '${l10n.eventDishServings(dish.servings)}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.dishIngredientsSectionTitle,
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              linesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.eventsLoadError,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                data: (lines) => lines.isEmpty
                    ? const _LinesEmpty()
                    : Column(
                        children: [
                          for (final line in lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _LineRow(
                                line: line,
                                unit: unitsById[line.unitId],
                                supplierCategory:
                                    line.supplierCategoryId == null
                                    ? null
                                    : categoriesById[line.supplierCategoryId],
                                onTap: () => context.push(
                                  '/event-dish-line-editor',
                                  extra: EventDishLineEditorArgs(
                                    eventDishId: eventDishId,
                                    line: line,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.unit,
    required this.supplierCategory,
    required this.onTap,
  });

  final EventDishLine line;
  final Unit? unit;
  final SupplierCategory? supplierCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(line.quantity);
    final measure = unit == null ? qty : '$qty ${unit!.name}';
    final hasNote = line.prepNote != null && line.prepNote!.trim().isNotEmpty;
    final parts = <String>[
      measure,
      if (hasNote) line.prepNote!.trim(),
      if (supplierCategory != null) supplierCategory!.name,
    ];

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.ingredientName,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.join(l10n.metadataSeparator),
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _LinesEmpty extends StatelessWidget {
  const _LinesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        l10n.eventDishLinesEmptyBody,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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

enum _OverflowAction { remove }
