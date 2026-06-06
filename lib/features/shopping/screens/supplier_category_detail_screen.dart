import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';

/// Supplier category detail screen (Spec 007 §2.3).
///
/// What is editable depends on the category kind (decision taken with the
/// project owner during 7A):
///
///   * **User categories** — name (monolingual, current locale), channel,
///     address, and a delete action.
///   * **System categories** — name is read-only (their shared translations
///     are never mutated from the app); only the per-group channel/address are
///     configurable. No delete.
///   * **Rebost (pantry)** — consultive, so it has no channel/address; name is
///     read-only and it cannot be deleted.
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
  final _addressController = TextEditingController();
  MessageChannel? _channel;
  bool _seeded = false;
  bool _saving = false;
  bool _deleting = false;
  String? _nameError;

  bool get _isPantry => isPantryCategory(widget.category.code);
  bool get _isUser => widget.category.isUserCategory;
  bool get _showChannel => !_isPantry;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.category.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _seed(Map<String, dynamic> settingsMap) {
    if (_seeded) return;
    final setting = settingsMap[widget.category.id];
    _channel = setting?.channel;
    _addressController.text = setting?.channelAddress ?? '';
    _seeded = true;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_isUser && _nameController.text.trim().isEmpty) {
      setState(() => _nameError = l10n.supplierCategoryNameRequired);
      return;
    }

    setState(() {
      _nameError = null;
      _saving = true;
    });
    try {
      final repo = ref.read(catalogRepositoryProvider);
      if (_isUser) {
        await repo.updateUserSupplierCategoryName(
          widget.category.id,
          _nameController.text,
        );
      }
      if (_showChannel) {
        final groupId = await ref.read(currentGroupIdProvider.future);
        final address = _addressController.text.trim();
        await ref.read(settingsRepositoryProvider).upsertSetting(
              groupId: groupId,
              supplierCategoryId: widget.category.id,
              channel: _channel,
              channelAddress: address.isEmpty ? null : address,
            );
      }
      ref.invalidate(supplierCategoriesProvider);
      ref.invalidate(groupSupplierSettingsProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    }
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
      ref.invalidate(groupSupplierSettingsProvider);
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
    final settingsAsync = ref.watch(groupSupplierSettingsProvider);
    final busy = _saving || _deleting;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: busy ? null : () => context.pop(),
        ),
        title: Text(widget.category.name, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: settingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _Message(text: l10n.settingsLoadError),
          data: (settingsMap) {
            _seed(settingsMap);
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
                FieldLabel(
                  label: l10n.supplierCategoryNameLabel,
                  child: _isUser
                      ? AppTextField(
                          controller: _nameController,
                          hintText: l10n.supplierCategoryNameHint,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        )
                      : _ReadOnlyField(value: widget.category.name),
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
                if (!_isUser) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.supplierCategorySystemNameHint,
                    style: AppTypography.caption,
                  ),
                ],
                if (_showChannel) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.settingsChannelLabel,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedChoice<MessageChannel?>(
                    value: _channel,
                    onChanged: (channel) => setState(() => _channel = channel),
                    options: [
                      SegmentedChoiceOption(
                        MessageChannel.whatsapp,
                        l10n.channelWhatsApp,
                      ),
                      SegmentedChoiceOption(
                        MessageChannel.email,
                        l10n.channelEmail,
                      ),
                      SegmentedChoiceOption(null, l10n.channelNone),
                    ],
                  ),
                  if (_channel != null) ...[
                    const SizedBox(height: 16),
                    FieldLabel(
                      label: _channel == MessageChannel.whatsapp
                          ? l10n.addressWhatsAppLabel
                          : l10n.addressEmailLabel,
                      child: AppTextField(
                        controller: _addressController,
                        hintText: _channel == MessageChannel.whatsapp
                            ? l10n.addressWhatsAppHint
                            : l10n.addressEmailHint,
                        keyboardType: _channel == MessageChannel.whatsapp
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.supplierCategoryPantryHint,
                    style: AppTypography.caption,
                  ),
                ],
                if (_isUser) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: busy ? null : _confirmDelete,
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
            onPressed: busy ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
