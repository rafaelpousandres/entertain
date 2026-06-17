import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_edit_session_host.dart';
import '../../photos/data/photo_storage.dart';
import '../../photos/widgets/photo_carousel_section.dart';
import '../data/catalog_providers.dart';
import '../data/ingredient.dart';
import '../data/reference_data.dart';
import '../widgets/unit_ordering.dart';

/// Create / edit form for a catalog ingredient (Specification 004 screen 4).
///
/// One widget for both modes. The reference catalogs (units, supplier
/// categories) and — in edit mode — the ingredient itself are resolved
/// before the form renders, so the pickers and the prefilled values are
/// available synchronously inside the form state.
class IngredientEditorScreen extends ConsumerWidget {
  const IngredientEditorScreen({
    super.key,
    this.ingredientId,
    this.initialSupplierCategoryId,
  });

  final String? ingredientId;

  /// §A: supplier category to preselect for a brand-new ingredient — the
  /// catalog's open accordion group. An editable default; ignored when editing.
  final String? initialSupplierCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final unitsAsync = ref.watch(unitsProvider(localeCode));
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));

    final ingredientAsync = ingredientId == null
        ? const AsyncValue<Ingredient?>.data(null)
        : ref.watch(ingredientByIdProvider(ingredientId!)).whenData((i) => i);

    final combined = [unitsAsync, categoriesAsync, ingredientAsync];
    // Only block on the *initial* load: a background refresh (e.g. after a
    // photo change invalidates ingredientByIdProvider, §1) keeps its previous
    // value, so the in-progress form must stay mounted rather than flash a
    // spinner and lose unsaved edits.
    if (combined.any((a) => a.isLoading && !a.hasValue)) {
      return const _Scaffold(child: _Loading());
    }
    if (combined.any((a) => a.hasError)) {
      return _Scaffold(
        child: _Error(
          message: l10n.ingredientsLoadError,
          onRetry: () {
            ref.invalidate(unitsProvider(localeCode));
            ref.invalidate(supplierCategoriesProvider(localeCode));
            if (ingredientId != null) {
              ref.invalidate(ingredientByIdProvider(ingredientId!));
            }
          },
        ),
      );
    }

    return _IngredientForm(
      ingredientId: ingredientId,
      initial: ingredientAsync.value,
      initialSupplierCategoryId: initialSupplierCategoryId,
      units: unitsAsync.value!,
      categories: categoriesAsync.value!,
    );
  }
}

class _IngredientForm extends ConsumerStatefulWidget {
  const _IngredientForm({
    this.ingredientId,
    this.initial,
    this.initialSupplierCategoryId,
    required this.units,
    required this.categories,
  });

  final String? ingredientId;
  final Ingredient? initial;
  final String? initialSupplierCategoryId;
  final List<Unit> units;
  final List<SupplierCategory> categories;

  bool get isEditing => ingredientId != null;

  @override
  ConsumerState<_IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends ConsumerState<_IngredientForm>
    with PhotoEditSessionHost<_IngredientForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _prepController;
  late IngredientDraft _draft;

  bool _saving = false;
  bool _deleting = false;
  bool _submitted = false;
  String? _nameError;
  String? _unitError;
  // §2.3: tracks user edits so the unsaved-changes guard knows when to prompt.
  bool _dirty = false;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial != null
        ? IngredientDraft.fromIngredient(widget.initial!)
        : IngredientDraft.empty();
    // §A: a brand-new ingredient inherits the catalog's open group as its
    // default supplier — an editable default the user can change below.
    if (widget.initial == null) {
      _draft.defaultSupplierCategoryId = widget.initialSupplierCategoryId;
    }
    _nameController = TextEditingController(text: _draft.name);
    _prepController = TextEditingController(text: _draft.prepDescription ?? '');
    // §2.6: snapshot the ingredient's photos so a Discard can roll back photo
    // changes made during this edit (photos exist only once the ingredient does).
    if (widget.isEditing) {
      initPhotoSession(MediaEntityType.ingredient, widget.ingredientId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  Unit? get _selectedUnit {
    final id = _draft.defaultUnitId;
    if (id == null) return null;
    for (final u in widget.units) {
      if (u.id == id) return u;
    }
    return null;
  }

  SupplierCategory? get _selectedCategory {
    final id = _draft.defaultSupplierCategoryId;
    if (id == null) return null;
    for (final c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _pickUnit() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.unitPickerTitle,
      selectedValue: _draft.defaultUnitId,
      options: [
        for (final u in orderUnitsForDisplay(widget.units))
          SingleChoiceOption(value: u.id, label: u.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _draft.defaultUnitId = id;
        _unitError = null;
      }),
    );
  }

  void _pickCategory() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.supplierPickerTitle,
      selectedValue: _draft.defaultSupplierCategoryId,
      clearLabel: l10n.supplierNoneLabel,
      onCleared: () => setState(() {
        _dirty = true;
        _draft.defaultSupplierCategoryId = null;
      }),
      options: [
        for (final c in widget.categories)
          SingleChoiceOption(value: c.id, label: c.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _draft.defaultSupplierCategoryId = id;
      }),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitted = true);
    _draft.name = _nameController.text;
    _draft.prepDescription = _prepController.text;

    final nameError = _draft.name.trim().isEmpty
        ? l10n.ingredientNameRequired
        : null;
    final unitError = _draft.defaultUnitId == null
        ? l10n.ingredientUnitRequired
        : null;
    if (nameError != null || unitError != null) {
      setState(() {
        _nameError = nameError;
        _unitError = unitError;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _unitError = null;
      _saving = true;
    });

    final repo = ref.read(catalogRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateIngredient(widget.ingredientId!, _draft);
        ref.invalidate(ingredientByIdProvider(widget.ingredientId!));
      } else {
        final groupId = await ref.read(currentGroupIdProvider.future);
        await repo.createIngredient(_draft, groupId: groupId);
      }
      ref.invalidate(ingredientsListProvider);
      // §2.6: the edit is confirmed — purge any buffered photo blobs the saved
      // state no longer references.
      await commitPhotoSession();
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ingredientSaveError)));
    }
  }

  /// §2.6: on Discard, roll the photo changes back to the pre-edit state; warn
  /// and stay in the editor if the rollback fails partway (returns false).
  Future<bool> _discardPhotos() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await rollbackPhotoSession();
    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.photoRollbackWarning)),
      );
    }
    return ok;
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.deleteIngredientConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.deleteIngredientConfirmBody,
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
              l10n.deleteIngredientConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      // Spec 010 §2.4: clear the ingredient's media rows (the soft delete never
      // fires the cleanup trigger) and purge their blobs (non-fatal), then
      // soft-delete the ingredient.
      try {
        final paths = await ref
            .read(mediaRepositoryProvider)
            .deleteForEntity(MediaEntityType.ingredient, widget.ingredientId!);
        await ref
            .read(photoStorageProvider)
            .remove(MediaEntityType.ingredient.bucket, paths);
      } catch (_) {}
      await ref
          .read(catalogRepositoryProvider)
          .deleteIngredient(widget.ingredientId!);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(ingredientByIdProvider(widget.ingredientId!));
      ref.invalidate(entityCoverPathsProvider(MediaEntityType.ingredient));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ingredientSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EditScaffold(
      title: widget.isEditing
          ? l10n.ingredientEditScreenTitle
          : l10n.ingredientNewScreenTitle,
      // §2.6: photo changes also count as unsaved.
      hasUnsavedChanges: _dirty || photosDirty,
      busy: _busy,
      onSave: _busy ? null : _save,
      onDiscard: _discardPhotos,
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
                case _OverflowAction.delete:
                  _confirmDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _OverflowAction.delete,
                child: Text(
                  l10n.deleteAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Spec 010 §2.3: the ingredient's photo carousel sits at the top,
          // above the name field. Available once the ingredient exists (a new
          // one gets its photos after the first save), so it is shown only when
          // editing.
          if (widget.isEditing) ...[
            PhotoCarouselSection(
              type: MediaEntityType.ingredient,
              entityId: widget.ingredientId!,
            ),
            const SizedBox(height: 20),
          ],
          FieldLabel(
            label: l10n.ingredientNameLabel,
            child: AppTextField(
              controller: _nameController,
              hintText: l10n.ingredientNameHint,
              onChanged: (value) {
                _dirty = true;
                if (_submitted) {
                  setState(() {
                    _nameError = value.trim().isEmpty
                        ? l10n.ingredientNameRequired
                        : null;
                  });
                }
              },
            ),
          ),
          if (_nameError != null) _FieldError(message: _nameError!),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.ingredientUnitLabel,
            child: FormFieldTile(
              onTap: _pickUnit,
              placeholder: l10n.ingredientUnitHint,
              value: _selectedUnit?.name,
            ),
          ),
          if (_unitError != null) _FieldError(message: _unitError!),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.ingredientSupplierLabel,
            child: FormFieldTile(
              onTap: _pickCategory,
              placeholder: l10n.ingredientSupplierHint,
              value: _selectedCategory?.name,
              onClear: _draft.defaultSupplierCategoryId == null
                  ? null
                  : () => setState(() {
                      _dirty = true;
                      _draft.defaultSupplierCategoryId = null;
                    }),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.ingredientPrepLabel,
            child: AppTextField(
              controller: _prepController,
              hintText: l10n.ingredientPrepHint,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => _dirty = true,
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

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(),
      body: SafeArea(top: false, child: child),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

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

enum _OverflowAction { delete }
