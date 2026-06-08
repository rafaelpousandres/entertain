import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/single_choice_sheet.dart';
import '../data/catalog_providers.dart';
import '../data/dish.dart';
import '../data/ingredient.dart';
import '../data/reference_data.dart';
import '../widgets/ingredient_picker.dart';
import '../widgets/unit_ordering.dart';

/// Result handed back to the dish editor when the line editor pops.
class LineEditorResult {
  const LineEditorResult({this.line, this.removed = false});

  /// The edited / created line, when saving.
  final DishLineDraft? line;

  /// True when the user removed the line from the dish.
  final bool removed;
}

/// Ingredient line editor (Specification 004 screen 3). Edits one in-memory
/// `dish_ingredients` line of the dish being edited and pops a
/// [LineEditorResult]; it never writes to the dish itself (the dish editor
/// commits all lines on save). It does, however, persist a brand-new
/// ingredient immediately when created on the fly via the picker.
///
/// `extra` carries the existing [DishLineDraft] in edit mode, or null when
/// adding a new line.
class IngredientLineEditorScreen extends ConsumerStatefulWidget {
  const IngredientLineEditorScreen({super.key, this.initialLine});

  final DishLineDraft? initialLine;

  bool get isEditing => initialLine != null;

  @override
  ConsumerState<IngredientLineEditorScreen> createState() =>
      _IngredientLineEditorScreenState();
}

class _IngredientLineEditorScreenState
    extends ConsumerState<IngredientLineEditorScreen> {
  late final TextEditingController _quantityController;
  late final TextEditingController _prepController;

  String? _ingredientId;
  String? _ingredientName;
  String? _unitId;

  /// Spec 008 §2.5: the chosen supplier category for the picked ingredient.
  /// Resolved lazily — until the user picks an ingredient or touches the
  /// selector, the displayed value comes from the ingredient's stored default,
  /// so opening the editor reflects the current catalog-wide category.
  String? _supplierCategoryId;
  bool _categoryResolved = false;

  bool _submitted = false;
  // §2.3: tracks whether the form diverges from its initial state so the
  // unsaved-changes guard knows when to prompt on exit.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    final line = widget.initialLine;
    _ingredientId = line?.ingredientId;
    _ingredientName = line?.ingredientName;
    _unitId = line?.unitId;
    _quantityController = TextEditingController(
      text: line == null ? '' : formatQuantity(line.quantity),
    );
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
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dirty = true;
      _ingredientId = picked.id;
      _ingredientName = picked.name;
      // Reset the unit to the ingredient's default — its family may differ
      // from whatever was previously selected.
      _unitId = picked.defaultUnitId;
      // §2.5: adopt the newly picked ingredient's current default category.
      _supplierCategoryId = picked.defaultSupplierCategoryId;
      _categoryResolved = true;
      // Spec 006 §2.4: a brand-new line pre-fills the prep note with the
      // ingredient's default preparation (the level above), as a convenience.
      // Only when the field is still empty, so an explicit value the user has
      // already typed is never overwritten.
      if (!widget.isEditing &&
          _prepController.text.trim().isEmpty &&
          (picked.prepDescription?.trim().isNotEmpty ?? false)) {
        _prepController.text = picked.prepDescription!.trim();
      }
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
      onSelected: (id) => setState(() {
        _dirty = true;
        _unitId = id;
      }),
    );
  }

  Unit? _unitOf(List<Unit> units, String? id) {
    if (id == null) return null;
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  Ingredient? _ingredientOf(List<Ingredient> ingredients, String? id) {
    if (id == null) return null;
    for (final i in ingredients) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// The category to display / save: the user's choice once touched, otherwise
  /// the picked ingredient's stored default (Spec 008 §2.5).
  String? _resolvedCategoryId(List<Ingredient> ingredients) => _categoryResolved
      ? _supplierCategoryId
      : _ingredientOf(ingredients, _ingredientId)?.defaultSupplierCategoryId;

  void _pickSupplierCategory(
    List<SupplierCategory> categories,
    String? current,
  ) {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.supplierCategoryPickerTitle,
      selectedValue: current,
      options: [
        for (final c in categories)
          SingleChoiceOption(value: c.id, label: c.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _supplierCategoryId = id;
        _categoryResolved = true;
      }),
      onCleared: () => setState(() {
        _dirty = true;
        _supplierCategoryId = null;
        _categoryResolved = true;
      }),
      clearLabel: l10n.supplierCategoryNoneLabel,
    );
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final quantity = _parseQuantity();
    if (_ingredientId == null || quantity == null || _unitId == null) {
      return;
    }
    // §2.5: persist a supplier-category change on the ingredient itself
    // (catalog-wide) before handing the line back. The dish editor commits the
    // line list on its own save; the category lives on `ingredients`, so it is
    // written here, immediately, like a brand-new ingredient created on the fly.
    final ingredients =
        ref.read(ingredientsListProvider).value ?? const <Ingredient>[];
    final ingredient = _ingredientOf(ingredients, _ingredientId);
    final chosenCategory = _resolvedCategoryId(ingredients);
    if (ingredient != null &&
        chosenCategory != ingredient.defaultSupplierCategoryId) {
      await ref
          .read(catalogRepositoryProvider)
          .updateIngredientDefaultSupplierCategory(
            _ingredientId!,
            chosenCategory,
          );
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(ingredientByIdProvider(_ingredientId!));
    }
    if (!mounted) return;
    context.pop(
      LineEditorResult(
        line: DishLineDraft(
          ingredientId: _ingredientId!,
          ingredientName: _ingredientName ?? '',
          quantity: quantity,
          unitId: _unitId!,
          prepNote: _prepController.text,
        ),
      ),
    );
  }

  void _remove() => context.pop(const LineEditorResult(removed: true));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final unitsAsync = ref.watch(unitsProvider(localeCode));
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));

    final units = unitsAsync.value;
    final ingredients = ingredientsAsync.value;
    final categories = categoriesAsync.value;
    final loading = units == null || ingredients == null || categories == null;

    final unit = _unitOf(units ?? const [], _unitId);
    final quantityError = _submitted && _parseQuantity() == null;
    final unitAllowsChoice =
        unit != null && unitsForFamily(units ?? const [], unit).length > 1;
    final categoryId = _resolvedCategoryId(ingredients ?? const []);
    final supplierCategory = categoryId == null
        ? null
        : () {
            for (final c in categories ?? const <SupplierCategory>[]) {
              if (c.id == categoryId) return c;
            }
            return null;
          }();

    return EditScaffold(
      title: widget.isEditing
          ? l10n.lineEditorEditTitle
          : l10n.lineEditorNewTitle,
      hasUnsavedChanges: _dirty,
      onSave: loading ? null : _save,
      trailingActions: [
        if (widget.isEditing)
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
                // §2.5: supplier category, set on the ingredient (catalog-wide)
                // so a line built here lands in the right shopping group.
                FieldLabel(
                  label: l10n.lineSupplierCategoryLabel,
                  child: FormFieldTile(
                    onTap: _ingredientId == null
                        ? () {}
                        : () => _pickSupplierCategory(categories, categoryId),
                    placeholder: _ingredientId == null
                        ? l10n.lineSupplierCategoryPickIngredientFirst
                        : l10n.lineSupplierCategoryHint,
                    value: supplierCategory?.name,
                    onClear: categoryId == null
                        ? null
                        : () => setState(() {
                            _dirty = true;
                            _supplierCategoryId = null;
                            _categoryResolved = true;
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
              ],
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
