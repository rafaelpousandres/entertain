import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
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
  final _supplierNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  /// Fixes §2.1: the *default* channel for outgoing messages; phone and email
  /// are stored independently below, and this marks which one the composer uses
  /// unless overridden for a single send.
  MessageChannel? _channel;
  bool _seeded = false;
  bool _saving = false;
  bool _deleting = false;
  String? _nameError;
  // §2.3: tracks user edits so the unsaved-changes guard knows when to prompt.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

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
    _supplierNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _seed(Map<String, dynamic> settingsMap) {
    if (_seeded) return;
    final setting = settingsMap[widget.category.id];
    _channel = setting?.channel;
    _supplierNameController.text = setting?.supplierName ?? '';
    _phoneController.text = setting?.phoneAddress ?? '';
    _emailController.text = setting?.emailAddress ?? '';
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
        final phone = _phoneController.text.trim();
        final email = _emailController.text.trim();
        final supplierName = _supplierNameController.text.trim();
        await ref
            .read(settingsRepositoryProvider)
            .upsertSetting(
              groupId: groupId,
              supplierCategoryId: widget.category.id,
              channel: _channel,
              phoneAddress: phone.isEmpty ? null : phone,
              emailAddress: email.isEmpty ? null : email,
              // Spec 008 §2.3: the concrete supplier name, per group.
              supplierName: supplierName.isEmpty ? null : supplierName,
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

    return EditScaffold(
      title: widget.category.name,
      hasUnsavedChanges: _dirty,
      busy: busy,
      onSave: busy ? null : _save,
      body: settingsAsync.when(
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
              // Spec 008 §2.3: the concrete supplier name ("Peixos Samba"),
              // free text, at the top of the screen — but not for the Rebost
              // pantry, which has no supplier behind it.
              if (_showChannel) ...[
                FieldLabel(
                  label: l10n.supplierNameLabel,
                  child: AppTextField(
                    controller: _supplierNameController,
                    hintText: l10n.supplierNameHint,
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FieldLabel(
                label: l10n.supplierCategoryCategoryLabel,
                child: _isUser
                    ? AppTextField(
                        controller: _nameController,
                        hintText: l10n.supplierCategoryNameHint,
                        onChanged: (_) {
                          _dirty = true;
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
                // Fixes round 2 §2.4: pair each preferred-channel option with
                // its address on the same row, so the link between a channel
                // and the address it sends to is immediate. Both addresses
                // stay stored and editable (Fixes §2.1); the non-selected rows
                // read as visually secondary. Compartir (round 2 §2.3) and Cap
                // need no address.
                const SizedBox(height: 24),
                Text(
                  l10n.supplierPreferredChannelLabel,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _ChannelRow(
                  icon: channelIcon(MessageChannel.whatsapp),
                  label: l10n.channelWhatsApp,
                  selected: _channel == MessageChannel.whatsapp,
                  onSelect: () => setState(() {
                    _dirty = true;
                    _channel = MessageChannel.whatsapp;
                  }),
                  field: AppTextField(
                    controller: _phoneController,
                    hintText: l10n.addressWhatsAppHint,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                const SizedBox(height: 10),
                _ChannelRow(
                  icon: channelIcon(MessageChannel.email),
                  label: l10n.channelEmail,
                  selected: _channel == MessageChannel.email,
                  onSelect: () => setState(() {
                    _dirty = true;
                    _channel = MessageChannel.email;
                  }),
                  field: AppTextField(
                    controller: _emailController,
                    hintText: l10n.addressEmailHint,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                const SizedBox(height: 10),
                _ChannelRow(
                  icon: channelIcon(MessageChannel.share),
                  label: l10n.channelShare,
                  selected: _channel == MessageChannel.share,
                  onSelect: () => setState(() {
                    _dirty = true;
                    _channel = MessageChannel.share;
                  }),
                  hint: l10n.supplierShareNoAddressHint,
                ),
                const SizedBox(height: 10),
                _ChannelRow(
                  icon: channelIcon(null),
                  label: l10n.channelNone,
                  selected: _channel == null,
                  onSelect: () => setState(() {
                    _dirty = true;
                    _channel = null;
                  }),
                ),
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
    );
  }
}

/// A preferred-channel option row (Fixes round 2 §2.4, restyled in round 3 §2.2):
/// a selection circle and a channel **icon** paired on the same row with the
/// channel's address [field] (WhatsApp / Email), a [hint] (Compartir — no
/// address needed), or nothing (Cap). The icon replaces the text label, which
/// truncated on narrow widths; [label] survives as the long-press tooltip.
/// Tapping the circle/icon selects the channel; the address field stays editable
/// and reads as secondary (dimmed) until its row is the selected one.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.field,
    this.hint,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final Widget? field;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.accentSecondary : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fixed-width selector + icon so the trailing fields line up vertically.
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: SizedBox(
              width: 62,
              child: Row(
                children: [
                  _SelectionCircle(selected: selected),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: label,
                    child: Icon(icon, size: 22, color: tint),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: switch ((field, hint)) {
            (final Widget f, _) => Opacity(
              opacity: selected ? 1 : 0.5,
              child: f,
            ),
            (null, final String h) => Text(h, style: AppTypography.caption),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

/// Design-system selection control (§5): an empty circle with a `disabled`
/// border when unselected; a filled `accent-secondary` circle with a white
/// check when selected.
class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accentSecondary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accentSecondary : AppColors.disabled,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppColors.onAccent)
          : null,
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
