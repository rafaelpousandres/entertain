import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../../util/search_text.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/catalog_providers.dart';
import '../data/ingredient.dart';
import '../data/reference_data.dart';
import 'unit_ordering.dart';

/// Searchable ingredient picker for the line editor (Specification 004
/// §3.5 / §6). Lists the group's ingredients, filters as the user types,
/// and always offers a low-friction "create new" path so a missing
/// ingredient can be added without leaving the dish being edited. Resolves
/// with the chosen (or freshly created) ingredient, or null if dismissed.
Future<Ingredient?> showIngredientPicker({
  required BuildContext context,
  required WidgetRef ref,
  required List<Ingredient> ingredients,
  required List<Unit> units,
  required List<SupplierCategory> categories,
  String? restrictToSupplierCategoryId,
}) {
  return showModalBottomSheet<Ingredient>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) => _IngredientPickerSheet(
      ref: ref,
      ingredients: ingredients,
      units: units,
      categories: categories,
      restrictToSupplierCategoryId: restrictToSupplierCategoryId,
    ),
  );
}

class _IngredientPickerSheet extends StatefulWidget {
  const _IngredientPickerSheet({
    required this.ref,
    required this.ingredients,
    required this.units,
    required this.categories,
    this.restrictToSupplierCategoryId,
  });

  final WidgetRef ref;
  final List<Ingredient> ingredients;
  final List<Unit> units;
  final List<SupplierCategory> categories;

  /// Spec 011 §2.11.b — when set, the picker shows ONLY catalog ingredients
  /// whose `default_supplier_category_id` matches this supplier (the section the
  /// extra is being added to); a strict filter with no "show all" escape. A
  /// freshly created ingredient inherits this supplier, fixed and non-editable.
  final String? restrictToSupplierCategoryId;

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Ingredient> get _filtered {
    final restrict = widget.restrictToSupplierCategoryId;
    final base = restrict == null
        ? widget.ingredients
        : widget.ingredients
              .where((i) => i.defaultSupplierCategoryId == restrict)
              .toList();
    // §2.11.d: accent- and case-insensitive — normalise both sides so "sip"
    // (or "Síp") matches "Sípia".
    final q = foldForSearch(_query.trim());
    if (q.isEmpty) return base;
    return base.where((i) => foldForSearch(i.name).contains(q)).toList();
  }

  Future<void> _createNew() async {
    final created = await showIngredientQuickCreate(
      context: context,
      ref: widget.ref,
      units: widget.units,
      categories: widget.categories,
      initialName: _query.trim(),
      fixedSupplierCategoryId: widget.restrictToSupplierCategoryId,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.ingredientPickerTitle,
                  style: AppTypography.sectionTitle,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppTextField(
                  controller: _searchController,
                  hintText: l10n.ingredientPickerSearchHint,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              _CreateNewRow(query: _query.trim(), onTap: _createNew),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        child: Text(
                          l10n.ingredientPickerEmpty,
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ingredient = filtered[index];
                          return _IngredientPickerRow(
                            name: ingredient.name,
                            onTap: () => Navigator.of(context).pop(ingredient),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateNewRow extends StatelessWidget {
  const _CreateNewRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = query.isEmpty
        ? l10n.ingredientPickerCreateNew
        : l10n.ingredientPickerCreateNamed(query);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: AppColors.accentSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientPickerRow extends StatelessWidget {
  const _IngredientPickerRow({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Text(name, style: AppTypography.body),
        ),
      ),
    );
  }
}

/// Minimal "create ingredient on the fly" flow. Spec 008 Fixes §2.2: the three
/// *structural* attributes of an ingredient — name, unit, and supplier category
/// — are all collected here, so a freshly created ingredient already lands in
/// the right shopping group (quantity and prep note are contextual to the line
/// and stay on the line editor). Supplier category defaults to "no category".
/// Persists a real catalog ingredient immediately and resolves with it.
Future<Ingredient?> showIngredientQuickCreate({
  required BuildContext context,
  required WidgetRef ref,
  required List<Unit> units,
  required List<SupplierCategory> categories,
  String? initialName,
  String? fixedSupplierCategoryId,
}) {
  return showModalBottomSheet<Ingredient>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) => _QuickCreateSheet(
      ref: ref,
      units: units,
      categories: categories,
      initialName: initialName,
      fixedSupplierCategoryId: fixedSupplierCategoryId,
    ),
  );
}

class _QuickCreateSheet extends StatefulWidget {
  const _QuickCreateSheet({
    required this.ref,
    required this.units,
    required this.categories,
    this.initialName,
    this.fixedSupplierCategoryId,
  });

  final WidgetRef ref;
  final List<Unit> units;
  final List<SupplierCategory> categories;
  final String? initialName;

  /// Spec 011 §2.11.b — when set, the supplier category is pre-fixed to this id
  /// and shown read-only (the extras flow: an extra always belongs to its
  /// section's supplier, with no override).
  final String? fixedSupplierCategoryId;

  @override
  State<_QuickCreateSheet> createState() => _QuickCreateSheetState();
}

class _QuickCreateSheetState extends State<_QuickCreateSheet> {
  late final TextEditingController _nameController;
  String? _unitId;
  String? _categoryId;
  bool _saving = false;
  bool _submitted = false;

  bool get _categoryLocked => widget.fixedSupplierCategoryId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _categoryId = widget.fixedSupplierCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Unit? get _selectedUnit {
    if (_unitId == null) return null;
    for (final u in widget.units) {
      if (u.id == _unitId) return u;
    }
    return null;
  }

  SupplierCategory? get _selectedCategory {
    if (_categoryId == null) return null;
    for (final c in widget.categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  void _pickUnit() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.unitPickerTitle,
      selectedValue: _unitId,
      options: [
        for (final u in orderUnitsForDisplay(widget.units))
          SingleChoiceOption(value: u.id, label: u.name),
      ],
      onSelected: (id) => setState(() => _unitId = id),
    );
  }

  void _pickCategory() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.supplierPickerTitle,
      selectedValue: _categoryId,
      clearLabel: l10n.supplierNoneLabel,
      onCleared: () => setState(() => _categoryId = null),
      options: [
        for (final c in widget.categories)
          SingleChoiceOption(value: c.id, label: c.name),
      ],
      onSelected: (id) => setState(() => _categoryId = id),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitted = true);
    final name = _nameController.text.trim();
    if (name.isEmpty || _unitId == null) return;

    setState(() => _saving = true);
    try {
      final groupId = await widget.ref.read(currentGroupIdProvider.future);
      final created = await widget.ref
          .read(catalogRepositoryProvider)
          .createIngredient(
            IngredientDraft(
              name: name,
              defaultUnitId: _unitId,
              // §2.2: persist the chosen supplier category at creation time so
              // the ingredient lands in the right shopping group from the start.
              defaultSupplierCategoryId: _categoryId,
            ),
            groupId: groupId,
          );
      widget.ref.invalidate(ingredientsListProvider);
      navigator.pop(created);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ingredientSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final nameEmpty = _nameController.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                l10n.quickCreateTitle,
                style: AppTypography.sectionTitle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: FieldLabel(
                label: l10n.ingredientNameLabel,
                child: AppTextField(
                  controller: _nameController,
                  hintText: l10n.ingredientNameHint,
                  autofocus:
                      widget.initialName == null || widget.initialName!.isEmpty,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            if (_submitted && nameEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: _InlineError(),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: FieldLabel(
                label: l10n.ingredientUnitLabel,
                child: FormFieldTile(
                  onTap: _pickUnit,
                  placeholder: l10n.ingredientUnitHint,
                  value: _selectedUnit?.name,
                ),
              ),
            ),
            if (_submitted && _unitId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(
                  l10n.ingredientUnitRequired,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // §2.2: supplier category is the third structural attribute, so it
            // sits here below the unit — defaulting to "no category". §2.11.b:
            // in the extras flow it is pre-fixed to the section's supplier and
            // shown read-only (no picker, no clear).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: FieldLabel(
                label: l10n.ingredientSupplierLabel,
                child: FormFieldTile(
                  onTap: _categoryLocked ? () {} : _pickCategory,
                  placeholder: l10n.ingredientSupplierHint,
                  value: _selectedCategory?.name,
                  onClear: (_categoryLocked || _categoryId == null)
                      ? null
                      : () => setState(() => _categoryId = null),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(
                label: l10n.createAction,
                icon: Icons.check,
                onPressed: _saving ? null : _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.ingredientNameRequired,
      style: AppTypography.caption.copyWith(color: AppColors.danger),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
