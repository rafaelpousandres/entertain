import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/stepper_field.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart'
    show formatQuantity, quantityDecimalSeparator;
import '../../catalog/data/dish_category.dart';
import '../../catalog/data/reference_data.dart';
import '../../shopping/data/shopping_providers.dart';
import '../data/event_dish_line.dart';
import '../data/events_providers.dart';
import '../data/serving_scale.dart';
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
      // Fixes §2.1: the removed dish's ingredients must disappear from the
      // shopping panel too, without a restart.
      ref.invalidate(eventShoppingProvider(eventId));
      // Spec 008 §2.4: removing a dish removes its ingredients, affecting status.
      ref.invalidate(eventReadinessProvider);
      ref.invalidate(eventsListProvider);
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

    // §2.1: the dish's description and preparation are not snapshotted onto the
    // event copy — they are read live from the catalog dish via source_dish_id,
    // so cooks always see the latest recipe. Null when the event-dish has no
    // source (origin deleted) or the catalog dish is unavailable.
    final sourceDishId = dishAsync.value?.sourceDishId;
    final catalogDish = sourceDishId == null
        ? null
        : ref.watch(dishByIdProvider(sourceDishId)).value;

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
          data: (dish) {
            final description = catalogDish?.description?.trim() ?? '';
            final preparation = catalogDish?.preparation?.trim() ?? '';
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Fixes round 2 §2.1: the description is the dish's subtitle, so
                // it sits directly under the title (in the app bar) and ahead of
                // the metadata line (title → description → metadata).
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  dishCategoryLabel(l10n, dish.category),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // §2.10: servings are editable here; ingredient quantities scale
                // to this value on display.
                _ServingsEditor(
                  eventId: eventId,
                  eventDishId: eventDishId,
                  servings: dish.servings,
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
                                  servings: dish.servings,
                                  unit: unitsById[line.unitId],
                                  supplierCategory:
                                      line.supplierCategoryId == null
                                      ? null
                                      : categoriesById[line.supplierCategoryId],
                                  onTap: () => context.push(
                                    '/event-dish-line-editor',
                                    extra: EventDishLineEditorArgs(
                                      eventId: eventId,
                                      eventDishId: eventDishId,
                                      line: line,
                                      sourceDishId: dish.sourceDishId,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                // §2.2: add a brand-new ad-hoc line to this event's copy. The
                // editor offers to also promote it to the catalog recipe.
                SecondaryButton(
                  label: l10n.addIngredientLineAction,
                  icon: Icons.add,
                  onPressed: () => context.push(
                    '/event-dish-line-editor',
                    extra: EventDishLineEditorArgs(
                      eventId: eventId,
                      eventDishId: eventDishId,
                      sourceDishId: dish.sourceDishId,
                    ),
                  ),
                ),
                // §2.1: the multi-line preparation as a longer block further
                // down, read live from the catalog recipe.
                if (preparation.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.dishPreparationSectionTitle,
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preparation,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.servings,
    required this.unit,
    required this.supplierCategory,
    required this.onTap,
  });

  final EventDishLine line;
  final int servings;
  final Unit? unit;
  final SupplierCategory? supplierCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // §2.10: show the quantity scaled to the event-dish servings.
    final scaled = scaleServingQuantity(
      base: line.quantity,
      referenceServings: line.referenceServings,
      targetServings: servings,
      countable: unit?.magnitude == UnitMagnitude.count,
    );
    final qty = formatQuantity(
      scaled,
      decimalSeparator: quantityDecimalSeparator(
        Localizations.localeOf(context).languageCode,
      ),
    );
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
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
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

/// Editable servings for an event-dish (Spec 008 §2.10). A positive-integer
/// stepper that persists each change and refreshes the lines (which rescale on
/// display) and the shopping panel. Holds a local value so the stepper responds
/// instantly while the write and re-fetch happen in the background.
class _ServingsEditor extends ConsumerStatefulWidget {
  const _ServingsEditor({
    required this.eventId,
    required this.eventDishId,
    required this.servings,
  });

  final String eventId;
  final String eventDishId;
  final int servings;

  @override
  ConsumerState<_ServingsEditor> createState() => _ServingsEditorState();
}

class _ServingsEditorState extends ConsumerState<_ServingsEditor> {
  late int _servings = widget.servings;

  @override
  void didUpdateWidget(_ServingsEditor old) {
    super.didUpdateWidget(old);
    // Keep in sync if the provider re-emits a different value (e.g. after the
    // screen is revisited) — but never clobber an in-flight local edit.
    if (old.servings != widget.servings && _servings != widget.servings) {
      _servings = widget.servings;
    }
  }

  Future<void> _change(int value) async {
    if (value < 1) return;
    setState(() => _servings = value);
    await ref
        .read(eventsRepositoryProvider)
        .updateEventDishServings(widget.eventDishId, value);
    ref.invalidate(eventDishByIdProvider(widget.eventDishId));
    ref.invalidate(eventDishLinesProvider(widget.eventDishId));
    ref.invalidate(eventShoppingProvider(widget.eventId));
    // Fixes §2.1: the menu tab's dish card reads `servings` from the
    // event-dishes list, so that provider must be invalidated too — otherwise
    // the card keeps showing the old servings until the app is restarted.
    ref.invalidate(eventDishesProvider(widget.eventId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FieldLabel(
      label: l10n.eventDishServingsLabel,
      child: StepperField(value: _servings, onChanged: _change),
    );
  }
}
