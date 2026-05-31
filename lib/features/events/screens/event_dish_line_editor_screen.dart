import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart' show formatQuantity;
import '../../catalog/data/ingredient.dart';
import '../../catalog/data/reference_data.dart';
import '../../catalog/widgets/ingredient_picker.dart';
import '../../catalog/widgets/unit_ordering.dart';
import '../data/event_dish_line.dart';
import '../data/events_providers.dart';

/// Arguments for the per-event line editor: the line being edited and the
/// `event_dish` it belongs to (so the editor can invalidate the right list).
class EventDishLineEditorArgs {
  const EventDishLineEditorArgs({
    required this.eventDishId,
    required this.line,
  });

  final String eventDishId;
  final EventDishLine line;
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

  bool _submitted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final line = widget.args.line;
    _ingredientId = line.ingredientId;
    _ingredientName = line.ingredientName;
    _unitId = line.unitId;
    _supplierCategoryId = line.supplierCategoryId;
    _quantityController = TextEditingController(
      text: formatQuantity(line.quantity),
    );
    _prepController = TextEditingController(text: line.prepNote ?? '');
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
  ) async {
    final picked = await showIngredientPicker(
      context: context,
      ref: ref,
      ingredients: ingredients,
      units: units,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ingredientId = picked.id;
      _ingredientName = picked.name;
      // The new ingredient may belong to a different unit family; reset to its
      // default. The supplier override is deliberate per-event state, so it is
      // left untouched.
      _unitId = picked.defaultUnitId;
    });
  }

  void _pickUnit(List<Unit> units) {
    final l10n = AppLocalizations.of(context);
    final reference = _unitOf(units, _unitId);
    if (reference == null) return;
    final allowed = unitsForFamily(units, reference);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.unitPickerTitle,
      selectedValue: _unitId,
      options: [
        for (final u in allowed) SingleChoiceOption(value: u.id, label: u.name),
      ],
      onSelected: (id) => setState(() => _unitId = id),
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
      onSelected: (id) => setState(() => _supplierCategoryId = id),
      onCleared: () => setState(() => _supplierCategoryId = null),
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
    try {
      await ref
          .read(eventsRepositoryProvider)
          .updateEventDishLine(
            widget.args.line.id,
            ingredientId: _ingredientId!,
            ingredientName: _ingredientName ?? '',
            quantity: quantity,
            unitId: _unitId!,
            prepNote: _nullIfBlank(_prepController.text),
            supplierCategoryId: _supplierCategoryId,
          );
      ref.invalidate(eventDishLinesProvider(widget.args.eventDishId));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventDishSaveError)));
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .deleteEventDishLine(widget.args.line.id);
      ref.invalidate(eventDishLinesProvider(widget.args.eventDishId));
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
    final loading =
        units == null || ingredients == null || categories == null;

    final unit = _unitOf(units ?? const [], _unitId);
    final quantityError = _submitted && _parseQuantity() == null;
    final unitAllowsChoice =
        unit != null && unitsForFamily(units ?? const [], unit).length > 1;
    final categoriesById = {
      for (final c in categories ?? const <SupplierCategory>[]) c.id: c,
    };
    final supplierCategory = _supplierCategoryId == null
        ? null
        : categoriesById[_supplierCategoryId];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.lineEditorEditTitle, style: AppTypography.sectionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: _busy ? null : () => context.pop(),
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
                  _remove();
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
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  FieldLabel(
                    label: l10n.lineIngredientLabel,
                    child: FormFieldTile(
                      onTap: () => _pickIngredient(ingredients, units),
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
                            onChanged: (_) {
                              if (_submitted) setState(() {});
                            },
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
                    child: FormFieldTile(
                      onTap: () => _pickSupplierCategory(categories),
                      placeholder: l10n.lineSupplierCategoryHint,
                      value: supplierCategory?.name,
                      onClear: _supplierCategoryId == null
                          ? null
                          : () => setState(() => _supplierCategoryId = null),
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
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: PrimaryButton(
            label: l10n.saveAction,
            icon: Icons.check,
            onPressed: loading || _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
