import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart' show formatQuantity;
import '../../catalog/data/ingredient.dart';
import '../../catalog/data/reference_data.dart';
import '../../catalog/widgets/ingredient_picker.dart';
import '../../catalog/widgets/unit_ordering.dart';
import '../../shopping/data/shopping_providers.dart';
import '../data/event_dish_line.dart';
import '../data/events_providers.dart';
import '../data/serving_scale.dart';

/// Arguments for the per-event line editor: the line being edited and the
/// `event_dish` it belongs to (so the editor can invalidate the right list).
class EventDishLineEditorArgs {
  const EventDishLineEditorArgs({
    required this.eventId,
    required this.eventDishId,
    this.line,
    this.sourceDishId,
    this.initialSupplierCategoryId,
    this.lockSupplierCategory = false,
  });

  /// The owning event, so saving a line can refresh the event shopping panel
  /// (Fixes §2.1).
  final String eventId;
  final String eventDishId;

  /// The line being edited, or null when adding a brand-new ad-hoc line
  /// (Spec 006 §2.2).
  final EventDishLine? line;

  /// The catalog dish this event-dish copy came from (`source_dish_id`), so a
  /// new ad-hoc line can optionally be promoted to the catalog recipe (§2.2).
  /// Null when there is no source dish (origin deleted, or unknown), in which
  /// case the promote-to-recipe option is not offered.
  final String? sourceDishId;

  /// Spec 011 §2.11 — supplier to pre-select when adding a brand-new line, used
  /// by the "+ Add extra" flow to default to the section the user tapped from.
  /// Ignored when editing an existing line.
  final String? initialSupplierCategoryId;

  /// Spec 011 §2.11.b — the extras flow: the supplier category is fixed to the
  /// section's and not editable, and the ingredient picker shows only catalog
  /// ingredients whose default supplier is that category (strict, no override).
  final bool lockSupplierCategory;
}

/// Per-event ingredient line editor (Specification 004 §3.8). Analogous to
/// the catalog ingredient line editor, but it operates on an existing
/// `event_dish_ingredients` row and persists immediately (the `event_dish`
/// already exists, so there is no in-memory draft to commit later). It adds a
/// `supplier_category_id` override — the per-event supplier assignment,
/// including marking a line as pantry / "Rebost" for this event only.
class EventDishLineEditorScreen extends ConsumerStatefulWidget {
  const EventDishLineEditorScreen({super.key, required this.args});

  final EventDishLineEditorArgs args;

  @override
  ConsumerState<EventDishLineEditorScreen> createState() =>
      _EventDishLineEditorScreenState();
}

class _EventDishLineEditorScreenState
    extends ConsumerState<EventDishLineEditorScreen> {
  late final TextEditingController _quantityController;
  late final TextEditingController _prepController;

  String? _ingredientId;
  String? _ingredientName;
  String? _unitId;
  String? _supplierCategoryId;

  /// Whether the new ad-hoc line should also be written to the catalog recipe
  /// (§2.2). Only meaningful when adding and a source dish exists.
  bool _promoteToRecipe = false;

  bool _submitted = false;
  bool _busy = false;
  // §2.3: tracks user edits so the unsaved-changes guard knows when to prompt.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Spec 008 §2.10: the quantity field shows the *scaled* value (what the user
  /// sees elsewhere), seeded once the event-dish servings and units are known.
  bool _quantitySeeded = false;

  /// Adding a brand-new ad-hoc line vs. editing an existing one (§2.2).
  bool get _isAdding => widget.args.line == null;

  /// Whether the promote-to-recipe checkbox can be offered: only when adding,
  /// and only when the event-dish has a known source catalog dish to write to.
  bool get _canPromote => _isAdding && widget.args.sourceDishId != null;

  @override
  void initState() {
    super.initState();
    final line = widget.args.line;
    _ingredientId = line?.ingredientId;
    _ingredientName = line?.ingredientName;
    _unitId = line?.unitId;
    // §2.11: when adding, pre-select the supplier passed by the "+ Add extra"
    // flow (the section's supplier); otherwise none until an ingredient is set.
    _supplierCategoryId =
        line?.supplierCategoryId ?? widget.args.initialSupplierCategoryId;
    // The text is seeded in build once the event-dish servings are loaded, so
    // the field shows the scaled quantity. Adding a new line has nothing to
    // seed (the user types fresh for the current servings).
    _quantityController = TextEditingController();
    _quantitySeeded = line == null;
    _prepController = TextEditingController(text: line?.prepNote ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  double? _parseQuantity() {
    final raw = _quantityController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  Unit? _unitOf(List<Unit> units, String? id) {
    if (id == null) return null;
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> _pickIngredient(
    List<Ingredient> ingredients,
    List<Unit> units,
    List<SupplierCategory> categories,
  ) async {
    final picked = await showIngredientPicker(
      context: context,
      ref: ref,
      ingredients: ingredients,
      units: units,
      categories: categories,
      // §2.11.b: in the extras flow, restrict the catalog to ingredients of the
      // section's supplier, and fix that supplier on any new ingredient created.
      restrictToSupplierCategoryId: widget.args.lockSupplierCategory
          ? _supplierCategoryId
          : null,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dirty = true;
      _ingredientId = picked.id;
      _ingredientName = picked.name;
      // The new ingredient may belong to a different unit family; reset to its
      // default. When editing, the supplier override is deliberate per-event
      // state, so it is left untouched.
      _unitId = picked.defaultUnitId;
      // For a new ad-hoc line, default the supplier category to the
      // ingredient's default when none is set yet — mirroring copy-on-add, so
      // the line lands in the right shopping group instead of unassigned.
      if (_isAdding && _supplierCategoryId == null) {
        _supplierCategoryId = picked.defaultSupplierCategoryId;
      }
      // Spec 006 §2.4: a new ad-hoc line pre-fills the prep note with the
      // ingredient's default preparation (the level above), as a convenience.
      // Only when the field is still empty, so an explicit value is never
      // overwritten. Existing lines keep their stored value (no cascade).
      if (_isAdding &&
          _prepController.text.trim().isEmpty &&
          (picked.prepDescription?.trim().isNotEmpty ?? false)) {
        _prepController.text = picked.prepDescription!.trim();
      }
    });
  }

  void _pickUnit(List<Unit> units) {
    final l10n = AppLocalizations.of(context);
    // Mirrors the catalog line editor: the unit is a recipe decision, so offer
    // the full unit catalog (ordered by magnitude) with the current one
    // preselected, rather than locking it to the ingredient's default family.
    final allowed = orderUnitsForDisplay(units);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.unitPickerTitle,
      selectedValue: _unitId,
      options: [
        for (final u in allowed) SingleChoiceOption(value: u.id, label: u.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _unitId = id;
      }),
    );
  }

  void _pickSupplierCategory(List<SupplierCategory> categories) {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.supplierCategoryPickerTitle,
      selectedValue: _supplierCategoryId,
      options: [
        for (final c in categories)
          SingleChoiceOption(value: c.id, label: c.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _supplierCategoryId = id;
      }),
      onCleared: () => setState(() {
        _dirty = true;
        _supplierCategoryId = null;
      }),
      clearLabel: l10n.supplierCategoryNoneLabel,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitted = true);
    final quantity = _parseQuantity();
    if (_ingredientId == null || quantity == null || _unitId == null) {
      return;
    }

    setState(() => _busy = true);
    final prepNote = _nullIfBlank(_prepController.text);
    // Spec 008 §2.10: the entered quantity is the value for the event-dish's
    // current servings, so that becomes the line's scaling reference (a new
    // ad-hoc line, or a rebased edit).
    final referenceServings =
        ref
            .read(eventDishByIdProvider(widget.args.eventDishId))
            .value
            ?.servings ??
        widget.args.line?.referenceServings ??
        1;
    try {
      final eventsRepo = ref.read(eventsRepositoryProvider);
      if (_isAdding) {
        await eventsRepo.addEventDishLine(
          widget.args.eventDishId,
          ingredientId: _ingredientId!,
          ingredientName: _ingredientName ?? '',
          quantity: quantity,
          unitId: _unitId!,
          prepNote: prepNote,
          supplierCategoryId: _supplierCategoryId,
          referenceServings: referenceServings,
        );
        // §2.2: the catalog write happens only on save and only when the
        // checkbox is ticked — never as a pre-emptive side-effect.
        final sourceDishId = widget.args.sourceDishId;
        if (_promoteToRecipe && sourceDishId != null) {
          await ref
              .read(catalogRepositoryProvider)
              .addDishIngredientLine(
                sourceDishId,
                ingredientId: _ingredientId!,
                quantity: quantity,
                unitId: _unitId!,
                prepNote: prepNote,
              );
          ref.invalidate(dishLinesProvider(sourceDishId));
        }
      } else {
        await eventsRepo.updateEventDishLine(
          widget.args.line!.id,
          ingredientId: _ingredientId!,
          ingredientName: _ingredientName ?? '',
          quantity: quantity,
          unitId: _unitId!,
          prepNote: prepNote,
          supplierCategoryId: _supplierCategoryId,
          referenceServings: referenceServings,
        );
      }
      ref.invalidate(eventDishLinesProvider(widget.args.eventDishId));
      ref.invalidate(eventShoppingProvider(widget.args.eventId));
      // Spec 008 §2.4: adding / editing / removing a line changes the menu's
      // readiness, so the event's derived status may change.
      ref.invalidate(eventReadinessProvider);
      ref.invalidate(eventsListProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventDishSaveError)));
    }
  }

  Future<void> _confirmRemove() async {
    final l10n = AppLocalizations.of(context);
    // §2.11.e: an extra (the locked-supplier flow) lives on the invisible
    // phantom dish, so it gets shopping-list wording rather than the generic
    // "removes the line from this dish".
    final isExtra = widget.args.lockSupplierCategory;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isExtra ? l10n.removeExtraConfirmTitle : l10n.removeLineConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          isExtra ? l10n.removeExtraConfirmBody : l10n.removeLineConfirmBody,
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
              isExtra
                  ? l10n.removeExtraConfirmButton
                  : l10n.removeLineConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _remove();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .deleteEventDishLine(widget.args.line!.id);
      ref.invalidate(eventDishLinesProvider(widget.args.eventDishId));
      ref.invalidate(eventShoppingProvider(widget.args.eventId));
      // Spec 008 §2.4: adding / editing / removing a line changes the menu's
      // readiness, so the event's derived status may change.
      ref.invalidate(eventReadinessProvider);
      ref.invalidate(eventsListProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventDishSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final units = ref.watch(unitsProvider(localeCode)).value;
    final ingredients = ref.watch(ingredientsListProvider).value;
    final categories = ref.watch(supplierCategoriesProvider(localeCode)).value;
    final eventDish = ref
        .watch(eventDishByIdProvider(widget.args.eventDishId))
        .value;
    final loading =
        units == null ||
        ingredients == null ||
        categories == null ||
        eventDish == null;

    // §2.10: seed the quantity field once with the scaled value, so an existing
    // line edits the amount the user sees on the detail / shopping surfaces.
    if (!loading && !_quantitySeeded) {
      final line = widget.args.line;
      if (line != null) {
        final unit = _unitOf(units, line.unitId);
        _quantityController.text = formatQuantity(
          scaleServingQuantity(
            base: line.quantity,
            referenceServings: line.referenceServings,
            targetServings: eventDish.servings,
            countable: unit?.magnitude == UnitMagnitude.count,
          ),
        );
      }
      _quantitySeeded = true;
    }

    final unit = _unitOf(units ?? const [], _unitId);
    final quantityError = _submitted && _parseQuantity() == null;
    // Any line can pick from the full unit catalog, so the chooser is offered
    // whenever there is more than one unit to choose from.
    final unitAllowsChoice = unit != null && (units?.length ?? 0) > 1;
    final categoriesById = {
      for (final c in categories ?? const <SupplierCategory>[]) c.id: c,
    };
    final supplierCategory = _supplierCategoryId == null
        ? null
        : categoriesById[_supplierCategoryId];

    return EditScaffold(
      title: _isAdding ? l10n.lineEditorNewTitle : l10n.lineEditorEditTitle,
      hasUnsavedChanges: _dirty,
      busy: _busy,
      onSave: (loading || _busy) ? null : _save,
      trailingActions: [
        // Removing only applies to a line that already exists.
        if (!_isAdding)
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
                  _confirmRemove();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _OverflowAction.remove,
                child: Text(
                  l10n.removeLineAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
      ],
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                FieldLabel(
                  label: l10n.lineIngredientLabel,
                  child: FormFieldTile(
                    onTap: () =>
                        _pickIngredient(ingredients, units, categories),
                    placeholder: l10n.lineIngredientHint,
                    value: _ingredientName,
                  ),
                ),
                if (_submitted && _ingredientId == null)
                  _FieldError(message: l10n.lineIngredientRequired),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FieldLabel(
                        label: l10n.lineQuantityLabel,
                        child: AppTextField(
                          controller: _quantityController,
                          hintText: l10n.lineQuantityHint,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FieldLabel(
                        label: l10n.lineUnitLabel,
                        child: FormFieldTile(
                          onTap: _ingredientId == null
                              ? () {}
                              : () => _pickUnit(units),
                          placeholder: l10n.lineUnitHint,
                          value: unit?.name,
                          trailing: unitAllowsChoice
                              ? const Icon(
                                  Icons.expand_more,
                                  color: AppColors.textTertiary,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (quantityError)
                  _FieldError(message: l10n.lineQuantityInvalid),
                const SizedBox(height: 16),
                FieldLabel(
                  label: l10n.lineSupplierCategoryLabel,
                  // §2.11.b: the extras flow fixes the supplier to the section's
                  // and shows it read-only — no picker, no clear.
                  child: FormFieldTile(
                    onTap: widget.args.lockSupplierCategory
                        ? () {}
                        : () => _pickSupplierCategory(categories),
                    placeholder: l10n.lineSupplierCategoryHint,
                    value: supplierCategory?.name,
                    onClear:
                        (widget.args.lockSupplierCategory ||
                            _supplierCategoryId == null)
                        ? null
                        : () => setState(() {
                            _dirty = true;
                            _supplierCategoryId = null;
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                FieldLabel(
                  label: l10n.linePrepNoteLabel,
                  child: AppTextField(
                    controller: _prepController,
                    hintText: l10n.linePrepNoteHint,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                if (_canPromote) ...[
                  const SizedBox(height: 16),
                  _PromoteToRecipeCheckbox(
                    value: _promoteToRecipe,
                    onChanged: (v) => setState(() {
                      _dirty = true;
                      _promoteToRecipe = v;
                    }),
                  ),
                ],
              ],
            ),
    );
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Spec 006 §2.2: offers to also write a new ad-hoc line to the catalog recipe
/// pointed to by the event-dish's `source_dish_id`. Defaults to unchecked; the
/// supporting text makes clear the catalog change is irreversible from here
/// (it must be undone by editing the catalog directly).
class _PromoteToRecipeCheckbox extends StatelessWidget {
  const _PromoteToRecipeCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection control per design system §5.
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? AppColors.accentSecondary : Colors.transparent,
                  border: Border.all(
                    color: value
                        ? AppColors.accentSecondary
                        : AppColors.disabled,
                    width: 1.5,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check,
                        size: 15,
                        color: AppColors.onAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.promoteLineToRecipeLabel,
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.promoteLineToRecipeHint,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}

enum _OverflowAction { remove }
