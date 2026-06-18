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
import '../../shopping/supplier_category_format.dart';
import '../data/catalog_providers.dart';
import '../data/denomination.dart';
import '../data/drink.dart';
import '../data/reference_data.dart';

/// Create / edit a catalog drink (Spec 014 §2.2, refined by Spec 016 §3.2). The
/// units-only shape: name, supplier category (preselected to the system
/// "Begudes" category), a denomination (bottle, can, …), and photos. No
/// servings, no scaling.
class DrinkEditorScreen extends ConsumerWidget {
  const DrinkEditorScreen({
    super.key,
    this.drinkId,
    this.initialSupplierCategoryId,
  });

  final String? drinkId;

  /// §4b: supplier category to preselect for a brand-new drink — the catalog's
  /// open accordion category. An editable default; ignored when editing. Null
  /// falls back to the system "Begudes" category.
  final String? initialSupplierCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));

    final drinkAsync = drinkId == null
        ? const AsyncValue<Drink?>.data(null)
        : ref.watch(drinkByIdProvider(drinkId!)).whenData((d) => d);

    final combined = [categoriesAsync, drinkAsync];
    if (combined.any((a) => a.isLoading && !a.hasValue)) {
      return const _Scaffold(child: _Loading());
    }
    if (combined.any((a) => a.hasError)) {
      return _Scaffold(
        child: _Error(
          message: l10n.drinksLoadError,
          onRetry: () {
            ref.invalidate(supplierCategoriesProvider(localeCode));
            if (drinkId != null) ref.invalidate(drinkByIdProvider(drinkId!));
          },
        ),
      );
    }

    return _DrinkForm(
      drinkId: drinkId,
      initial: drinkAsync.value,
      categories: categoriesAsync.value!,
      initialSupplierCategoryId: initialSupplierCategoryId,
    );
  }
}

class _DrinkForm extends ConsumerStatefulWidget {
  const _DrinkForm({
    this.drinkId,
    this.initial,
    required this.categories,
    this.initialSupplierCategoryId,
  });

  final String? drinkId;
  final Drink? initial;
  final List<SupplierCategory> categories;
  final String? initialSupplierCategoryId;

  bool get isEditing => drinkId != null;

  @override
  ConsumerState<_DrinkForm> createState() => _DrinkFormState();
}

class _DrinkFormState extends ConsumerState<_DrinkForm>
    with PhotoEditSessionHost<_DrinkForm> {
  late final TextEditingController _nameController;
  late DrinkDraft _draft;

  bool _saving = false;
  bool _deleting = false;
  bool _submitted = false;
  String? _nameError;
  bool _dirty = false;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial != null
        ? DrinkDraft.fromDrink(widget.initial!)
        : DrinkDraft.empty();
    // §4b: a brand-new drink preselects the catalog's open accordion category
    // when one was passed; otherwise (Spec 016 §3.2) the system "Begudes"
    // category. Both are editable defaults.
    if (!widget.isEditing && _draft.supplierCategoryId == null) {
      if (widget.initialSupplierCategoryId != null) {
        _draft.supplierCategoryId = widget.initialSupplierCategoryId;
      } else {
        for (final c in widget.categories) {
          if (c.code == beveragesCategoryCode) {
            _draft.supplierCategoryId = c.id;
            break;
          }
        }
      }
    }
    _nameController = TextEditingController(text: _draft.name);
    if (widget.isEditing) {
      initPhotoSession(MediaEntityType.drink, widget.drinkId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  SupplierCategory? get _selectedCategory {
    final id = _draft.supplierCategoryId;
    if (id == null) return null;
    for (final c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _pickCategory() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.supplierPickerTitle,
      selectedValue: _draft.supplierCategoryId,
      clearLabel: l10n.supplierNoneLabel,
      onCleared: () => setState(() {
        _dirty = true;
        _draft.supplierCategoryId = null;
      }),
      options: [
        for (final c in widget.categories)
          SingleChoiceOption(value: c.id, label: c.name),
      ],
      onSelected: (id) => setState(() {
        _dirty = true;
        _draft.supplierCategoryId = id;
      }),
    );
  }

  /// Spec 016 §3.3: pick the drink's denomination from the predefined list,
  /// shown by localised singular ("ampolla", "llauna", …).
  void _pickDenomination() {
    final l10n = AppLocalizations.of(context);
    showSingleChoiceSheet<String>(
      context: context,
      title: l10n.drinkDenominationLabel,
      selectedValue: _draft.denomination,
      options: [
        for (final d in Denomination.values)
          SingleChoiceOption(
            value: d.wire,
            label: denominationName(l10n, d.wire),
          ),
      ],
      onSelected: (code) => setState(() {
        _dirty = true;
        _draft.denomination = code;
      }),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitted = true);
    _draft.name = _nameController.text;

    if (_draft.name.trim().isEmpty) {
      setState(() => _nameError = l10n.drinkNameRequired);
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final repo = ref.read(catalogRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateDrink(widget.drinkId!, _draft);
        ref.invalidate(drinkByIdProvider(widget.drinkId!));
      } else {
        final groupId = await ref.read(currentGroupIdProvider.future);
        await repo.createDrink(_draft, groupId: groupId);
      }
      ref.invalidate(drinksListProvider);
      await commitPhotoSession();
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.drinkSaveError)));
    }
  }

  Future<bool> _discardPhotos() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await rollbackPhotoSession();
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoRollbackWarning)));
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
          l10n.deleteDrinkConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.deleteDrinkConfirmBody,
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
              l10n.deleteDrinkConfirmButton,
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
      try {
        final paths = await ref
            .read(mediaRepositoryProvider)
            .deleteForEntity(MediaEntityType.drink, widget.drinkId!);
        await ref
            .read(photoStorageProvider)
            .remove(MediaEntityType.drink.bucket, paths);
      } catch (_) {}
      await ref.read(catalogRepositoryProvider).deleteDrink(widget.drinkId!);
      ref.invalidate(drinksListProvider);
      ref.invalidate(entityCoverPathsProvider(MediaEntityType.drink));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.drinkSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EditScaffold(
      title: widget.isEditing
          ? l10n.drinkEditScreenTitle
          : l10n.drinkNewScreenTitle,
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
                  l10n.deleteDrinkAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (widget.isEditing) ...[
            PhotoCarouselSection(
              type: MediaEntityType.drink,
              entityId: widget.drinkId!,
            ),
            const SizedBox(height: 20),
          ],
          FieldLabel(
            label: l10n.drinkNameLabel,
            child: AppTextField(
              controller: _nameController,
              hintText: l10n.drinkNameHint,
              onChanged: (value) {
                _dirty = true;
                if (_submitted) {
                  setState(() {
                    _nameError = value.trim().isEmpty
                        ? l10n.drinkNameRequired
                        : null;
                  });
                }
              },
            ),
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _nameError!,
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.lineSupplierCategoryLabel,
            child: FormFieldTile(
              onTap: _pickCategory,
              placeholder: l10n.lineSupplierCategoryHint,
              value: _selectedCategory?.name,
              onClear: _draft.supplierCategoryId == null
                  ? null
                  : () => setState(() {
                      _dirty = true;
                      _draft.supplierCategoryId = null;
                    }),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.drinkDenominationLabel,
            child: FormFieldTile(
              onTap: _pickDenomination,
              placeholder: l10n.drinkDenominationLabel,
              value: denominationName(l10n, _draft.denomination),
            ),
          ),
        ],
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

enum _OverflowAction { delete }
