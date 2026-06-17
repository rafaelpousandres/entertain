import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/secondary_button.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/group_supplier_setting.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';
import 'supplier_editor_screen.dart';

/// Supplier category screen (Spec 007 §2.3, generalised by Spec 013 §2.2).
///
/// Now a per-category **list of suppliers** instead of a single config form.
/// What is editable depends on the category kind:
///
///   * **User categories** — rename + delete the category here, plus manage its
///     suppliers.
///   * **System categories** — name read-only (their shared translations are
///     never mutated from the app); manage suppliers only.
///   * **Rebost (pantry)** — consultive, so it has no suppliers at all.
///
/// Each concrete supplier (name + channel + phone/email + default flag) is added
/// and edited in [SupplierEditorScreen]; one supplier per category is the
/// default, used silently / preselected at order time (Spec 013 §2.3).
class SupplierCategoryDetailScreen extends ConsumerStatefulWidget {
  const SupplierCategoryDetailScreen({super.key, required this.category});

  final SupplierCategory category;

  @override
  ConsumerState<SupplierCategoryDetailScreen> createState() =>
      _SupplierCategoryDetailScreenState();
}

class _SupplierCategoryDetailScreenState
    extends ConsumerState<SupplierCategoryDetailScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _deleting = false;
  bool _busyDefault = false;
  String? _nameError;
  bool _nameDirty = false;

  bool get _busy => _saving || _deleting || _busyDefault;
  bool get _isPantry => isPantryCategory(widget.category.code);
  bool get _isUser => widget.category.isUserCategory;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.category.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// User categories only: persist the renamed category in place (no pop — the
  /// screen stays open so the user can keep managing suppliers).
  Future<void> _saveName() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = l10n.supplierCategoryNameRequired);
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    try {
      await ref
          .read(catalogRepositoryProvider)
          .updateUserSupplierCategoryName(
            widget.category.id,
            _nameController.text,
          );
      ref.invalidate(supplierCategoriesProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameDirty = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    }
  }

  Future<void> _setDefault(GroupSupplierSetting supplier) async {
    if (supplier.isDefault) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyDefault = true);
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      await ref
          .read(settingsRepositoryProvider)
          .setDefaultSupplier(
            groupId: groupId,
            supplierCategoryId: widget.category.id,
            supplierId: supplier.id,
          );
      ref.invalidate(groupSuppliersByCategoryProvider);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
      }
    } finally {
      if (mounted) setState(() => _busyDefault = false);
    }
  }

  void _addSupplier() {
    context.push(
      '/settings/supplier',
      extra: SupplierEditorArgs(category: widget.category),
    );
  }

  void _editSupplier(GroupSupplierSetting supplier) {
    context.push(
      '/settings/supplier',
      extra: SupplierEditorArgs(category: widget.category, supplier: supplier),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.deleteSupplierCategoryConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.deleteSupplierCategoryConfirmBody,
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
              l10n.deleteSupplierCategoryConfirmButton,
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
      await ref
          .read(catalogRepositoryProvider)
          .deleteUserSupplierCategory(widget.category.id);
      ref.invalidate(supplierCategoriesProvider);
      ref.invalidate(groupSuppliersByCategoryProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deleteSupplierCategoryError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suppliersAsync = ref.watch(groupSuppliersByCategoryProvider);

    return EditScaffold(
      title: widget.category.name,
      hasUnsavedChanges: _isUser && _nameDirty,
      busy: _busy,
      // Only user categories have something to save at the category level (the
      // name); suppliers are saved in their own editor.
      onSave: (_isUser && !_busy) ? _saveName : null,
      body: suppliersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, _) => _Message(text: l10n.settingsLoadError),
        data: (byCategory) {
          final suppliers =
              byCategory[widget.category.id] ?? const <GroupSupplierSetting>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Icon(
                    supplierCategoryIcon(widget.category.code),
                    size: 22,
                    color: AppColors.accentSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.category.name,
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isUser) ...[
                FieldLabel(
                  label: l10n.supplierCategoryCategoryLabel,
                  child: AppTextField(
                    controller: _nameController,
                    hintText: l10n.supplierCategoryNameHint,
                    onChanged: (_) {
                      _nameDirty = true;
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                ),
                if (_nameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _nameError!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ] else
                Text(
                  l10n.supplierCategorySystemNameHint,
                  style: AppTypography.caption,
                ),
              if (_isPantry) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.supplierCategoryPantryHint,
                  style: AppTypography.caption,
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  l10n.suppliersSectionTitle,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (suppliers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      l10n.suppliersEmptyHint,
                      style: AppTypography.caption,
                    ),
                  )
                else
                  for (final supplier in suppliers) ...[
                    _SupplierRow(
                      supplier: supplier,
                      onTap: () => _editSupplier(supplier),
                      onSetDefault: _busy ? null : () => _setDefault(supplier),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 4),
                SecondaryButton(
                  label: l10n.addSupplierAction,
                  icon: Icons.add,
                  onPressed: _busy ? null : _addSupplier,
                ),
              ],
              if (_isUser) ...[
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _confirmDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    label: Text(
                      l10n.deleteSupplierCategoryAction,
                      style: AppTypography.button.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One supplier in the category list: a default star (tap to make it the
/// default), the supplier's label + channel summary, and a chevron to edit.
class _SupplierRow extends StatelessWidget {
  const _SupplierRow({
    required this.supplier,
    required this.onTap,
    required this.onSetDefault,
  });

  final GroupSupplierSetting supplier;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = supplierChannelSummary(l10n, supplier);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  supplier.isDefault ? Icons.star : Icons.star_border,
                  color: supplier.isDefault
                      ? AppColors.accentSecondary
                      : AppColors.textTertiary,
                  size: 22,
                ),
                tooltip: supplier.isDefault
                    ? l10n.supplierDefaultBadge
                    : l10n.supplierSetDefaultAction,
                onPressed: supplier.isDefault ? null : onSetDefault,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            supplierDisplayLabel(l10n, supplier),
                            style: AppTypography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (supplier.isDefault) ...[
                          const SizedBox(width: 8),
                          _DefaultBadge(label: l10n.supplierDefaultBadge),
                        ],
                      ],
                    ),
                    if (summary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
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

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSecondarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.accentSecondary),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
