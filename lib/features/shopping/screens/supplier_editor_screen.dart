import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/contact_picker.dart';
import '../data/group_supplier_setting.dart';
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../data/supplier_resolution.dart';
import '../supplier_category_format.dart';
import '../widgets/phone_field.dart';

/// RFC 5322-subset email check (the HTML5 `type=email` grammar): a local part of
/// permitted characters, an `@`, then one or more dot-separated labels. Gates
/// the supplier email and the email channel (Spec 009 §3).
final _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
);

bool isValidSupplierEmail(String value) => _emailRegExp.hasMatch(value.trim());

/// Arguments for the per-supplier editor (Spec 013 §2.2): the category the
/// supplier belongs to and the supplier being edited (null when adding).
class SupplierEditorArgs {
  const SupplierEditorArgs({required this.category, this.supplier});

  final SupplierCategory category;
  final GroupSupplierSetting? supplier;
}

/// Create / edit one concrete supplier under a category (Spec 013). Holds the
/// supplier name + the preferred channel and its phone/email, mirroring the
/// former per-category form — but now operating on a single
/// `group_supplier_settings` row by id, so a category can have several. The
/// default flag is managed from the category list (a supplier auto-becomes the
/// default when it is the first one of its category).
class SupplierEditorScreen extends ConsumerStatefulWidget {
  const SupplierEditorScreen({super.key, required this.args});

  final SupplierEditorArgs args;

  bool get isEditing => args.supplier != null;

  @override
  ConsumerState<SupplierEditorScreen> createState() =>
      _SupplierEditorScreenState();
}

class _SupplierEditorScreenState extends ConsumerState<SupplierEditorScreen> {
  final _supplierNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  MessageChannel? _channel;
  String _phoneDialCode = defaultPhoneDialCode();
  bool _saving = false;
  bool _deleting = false;
  String? _phoneError;
  String? _emailError;
  bool _dirty = false;

  bool get _busy => _saving || _deleting;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    final s = widget.args.supplier;
    _channel = s?.channel;
    _supplierNameController.text = s?.supplierName ?? '';
    final phone = splitStoredPhone(s?.phoneAddress);
    _phoneDialCode = phone.dialCode;
    _phoneController.text = phone.local;
    _emailController.text = s?.emailAddress ?? '';
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // §3: validate the phone and email formats, and ensure the selected channel
    // actually has a valid address behind it, before persisting.
    final localPhone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final phoneInvalid = localPhone.isNotEmpty && !isValidLocalPhone(localPhone);
    final emailInvalid = email.isNotEmpty && !isValidSupplierEmail(email);
    final whatsappNeedsPhone =
        _channel == MessageChannel.whatsapp && !isValidLocalPhone(localPhone);
    final emailNeedsEmail =
        _channel == MessageChannel.email && !isValidSupplierEmail(email);
    if (phoneInvalid || emailInvalid || whatsappNeedsPhone || emailNeedsEmail) {
      setState(() {
        _phoneError = (phoneInvalid || whatsappNeedsPhone)
            ? l10n.supplierPhoneInvalid
            : null;
        _emailError = (emailInvalid || emailNeedsEmail)
            ? l10n.supplierEmailInvalid
            : null;
      });
      return;
    }

    setState(() {
      _phoneError = null;
      _emailError = null;
      _saving = true;
    });
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final phone = composeStoredPhone(_phoneDialCode, _phoneController.text);
      final supplierName = _supplierNameController.text.trim();
      final values = (
        channel: _channel,
        phoneAddress: phone.isEmpty ? null : phone,
        emailAddress: email.isEmpty ? null : email,
        supplierName: supplierName.isEmpty ? null : supplierName,
      );
      if (widget.isEditing) {
        await repo.updateSupplier(
          supplierId: widget.args.supplier!.id,
          channel: values.channel,
          phoneAddress: values.phoneAddress,
          emailAddress: values.emailAddress,
          supplierName: values.supplierName,
        );
      } else {
        final groupId = await ref.read(currentGroupIdProvider.future);
        // The first supplier of a category becomes its default automatically.
        final existing =
            ref.read(groupSuppliersByCategoryProvider).value?[widget
                    .args
                    .category
                    .id] ??
            const <GroupSupplierSetting>[];
        await repo.insertSupplier(
          groupId: groupId,
          supplierCategoryId: widget.args.category.id,
          channel: values.channel,
          phoneAddress: values.phoneAddress,
          emailAddress: values.emailAddress,
          supplierName: values.supplierName,
          isDefault: existing.isEmpty,
        );
      }
      ref.invalidate(groupSuppliersByCategoryProvider);
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
          l10n.deleteSupplierConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.deleteSupplierConfirmBody,
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
              l10n.deleteAction,
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
    final supplier = widget.args.supplier!;
    setState(() => _deleting = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.deleteSupplier(supplier.id);
      // Promote a replacement default when the deleted supplier was the default
      // and the category still has others — a category never silently loses its
      // default while suppliers remain.
      if (supplier.isDefault) {
        final groupId = await ref.read(currentGroupIdProvider.future);
        final remaining = resolveSuppliersForCategory(
          (ref.read(groupSuppliersByCategoryProvider).value?[supplier
                  .supplierCategoryId] ??
              const <GroupSupplierSetting>[]),
          supplier.supplierCategoryId,
        ).suppliers.where((s) => s.id != supplier.id).toList();
        if (remaining.isNotEmpty) {
          await repo.setDefaultSupplier(
            groupId: groupId,
            supplierCategoryId: supplier.supplierCategoryId,
            supplierId: remaining.first.id,
          );
        }
      }
      ref.invalidate(groupSuppliersByCategoryProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    }
  }

  /// §3: a channel can only be selected when its address is valid — WhatsApp
  /// needs a valid phone, Email a valid email. Share / None never need one.
  void _selectChannel(MessageChannel? channel) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (channel == MessageChannel.whatsapp &&
        !isValidLocalPhone(_phoneController.text)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.channelNeedsValidPhone)),
      );
      return;
    }
    if (channel == MessageChannel.email &&
        !isValidSupplierEmail(_emailController.text)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.channelNeedsValidEmail)),
      );
      return;
    }
    setState(() {
      _dirty = true;
      _channel = channel;
    });
  }

  void _onPhoneChanged(String value) {
    setState(() {
      _dirty = true;
      if (_phoneError != null && isValidLocalPhone(value)) _phoneError = null;
    });
  }

  void _onEmailChanged(String value) {
    setState(() {
      _dirty = true;
      if (_emailError != null && isValidSupplierEmail(value)) _emailError = null;
    });
  }

  void _applyContactPhone(String raw) {
    var value = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    final split = splitStoredPhone(value);
    _phoneDialCode = split.dialCode;
    _phoneController.text = split.local;
  }

  /// Spec 009 §2.3: requests contacts permission, opens the device picker and
  /// autofills the supplier name, phone and email from the chosen contact.
  Future<void> _pickFromContacts() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await pickContact();
    if (!mounted) return;

    switch (result.status) {
      case ContactPickStatus.cancelled:
        return;
      case ContactPickStatus.denied:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.contactsPermissionDeniedBody)),
        );
        return;
      case ContactPickStatus.permanentlyDenied:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.contactsPermissionDeniedBody),
            action: SnackBarAction(
              label: l10n.openSettingsAction,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      case ContactPickStatus.picked:
        break;
    }

    final contact = result.contact!;
    if (contact.name != null && contact.name!.isNotEmpty) {
      _supplierNameController.text = contact.name!;
    }
    final phone = await _chooseContactValue(
      contact.phones,
      l10n.contactPickPhoneTitle,
    );
    if (phone != null) _applyContactPhone(phone);
    if (!mounted) return;
    final email = await _chooseContactValue(
      contact.emails,
      l10n.contactPickEmailTitle,
    );
    if (email != null) _emailController.text = email;
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  Future<String?> _chooseContactValue(
    List<String> options,
    String title,
  ) async {
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first;
    String? chosen;
    await showSingleChoiceSheet<String>(
      context: context,
      title: title,
      options: [
        for (final o in options) SingleChoiceOption(value: o, label: o),
      ],
      selectedValue: null,
      onSelected: (v) => chosen = v,
    );
    return chosen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EditScaffold(
      title: widget.isEditing
          ? l10n.supplierEditorEditTitle
          : l10n.supplierEditorNewTitle,
      hasUnsavedChanges: _dirty,
      busy: _busy,
      onSave: _busy ? null : _save,
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
                  l10n.deleteSupplierAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Icon(
                supplierCategoryIcon(widget.args.category.code),
                size: 22,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.args.category.name,
                  style: AppTypography.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Spec 008 §2.3: the concrete supplier name ("Peixos Samba"), free text.
          FieldLabel(
            label: l10n.supplierNameLabel,
            child: AppTextField(
              controller: _supplierNameController,
              hintText: l10n.supplierNameHint,
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.supplierPreferredChannelLabel,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _ChannelRow(
            icon: channelIcon(MessageChannel.whatsapp),
            label: l10n.channelWhatsApp,
            selected: _channel == MessageChannel.whatsapp,
            onSelect: () => _selectChannel(MessageChannel.whatsapp),
            field: PhoneField(
              dialCode: _phoneDialCode,
              controller: _phoneController,
              hintText: l10n.addressWhatsAppHint,
              onDialCodeChanged: (code) =>
                  setState(() => _phoneDialCode = code),
              onChanged: _onPhoneChanged,
            ),
          ),
          if (_phoneError != null) _FieldError(message: _phoneError!),
          const SizedBox(height: 10),
          _ChannelRow(
            icon: channelIcon(MessageChannel.email),
            label: l10n.channelEmail,
            selected: _channel == MessageChannel.email,
            onSelect: () => _selectChannel(MessageChannel.email),
            field: AppTextField(
              controller: _emailController,
              hintText: l10n.addressEmailHint,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              onChanged: _onEmailChanged,
            ),
          ),
          if (_emailError != null) _FieldError(message: _emailError!),
          const SizedBox(height: 10),
          _ChannelRow(
            icon: channelIcon(MessageChannel.share),
            label: l10n.channelShare,
            selected: _channel == MessageChannel.share,
            onSelect: () => _selectChannel(MessageChannel.share),
            hint: l10n.supplierShareNoAddressHint,
          ),
          const SizedBox(height: 10),
          _ChannelRow(
            icon: channelIcon(null),
            label: l10n.channelNone,
            selected: _channel == null,
            onSelect: () => _selectChannel(null),
          ),
          const SizedBox(height: 24),
          SecondaryButton(
            label: l10n.pickFromContactsAction,
            icon: Icons.contacts_outlined,
            onPressed: _busy ? null : _pickFromContacts,
          ),
        ],
      ),
    );
  }
}

/// A preferred-channel option row (Fixes round 2 §2.4, round 3 §2.2): a
/// selection circle + channel icon paired with the channel's address [field]
/// (WhatsApp / Email), a [hint] (Compartir — no address), or nothing (Cap).
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
            (final Widget f, _) => Opacity(opacity: selected ? 1 : 0.5, child: f),
            (null, final String h) => Text(h, style: AppTypography.caption),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70, top: 4),
      child: Text(
        message,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}

enum _OverflowAction { delete }
