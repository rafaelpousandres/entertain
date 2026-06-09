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
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/contact_picker.dart';
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';
import '../widgets/phone_field.dart';

/// RFC 5322-subset email check (the HTML5 `type=email` grammar): a local part of
/// permitted characters, an `@`, then one or more dot-separated labels. Used to
/// validate the supplier email and to gate the email channel (Spec 009 §3).
final _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
);

bool isValidSupplierEmail(String value) => _emailRegExp.hasMatch(value.trim());

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
  // §3: the phone's international dialling prefix; the controller above holds
  // only the local part. Stored recombined as E.164 (`+34600123456`).
  String _phoneDialCode = defaultPhoneDialCode();
  bool _seeded = false;
  bool _saving = false;
  bool _deleting = false;
  String? _nameError;
  String? _phoneError;
  String? _emailError;
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
    // §3: split the stored E.164 number into its prefix + local part to edit.
    final phone = splitStoredPhone(setting?.phoneAddress);
    _phoneDialCode = phone.dialCode;
    _phoneController.text = phone.local;
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

    // §3: validate the phone and email formats, and ensure the *selected*
    // channel actually has a valid address behind it, before persisting.
    if (_showChannel) {
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
    }

    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
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
        // §3: recombine the prefix + local part into the stored E.164 value.
        final phone = composeStoredPhone(_phoneDialCode, _phoneController.text);
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

  /// §3: a channel can only be *selected* when its address is valid — WhatsApp
  /// needs a valid phone, Email a valid email. Share and None never need one.
  /// Tapping a guarded channel with no valid address shows a hint instead of
  /// selecting it, so the user understands why nothing happened.
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

  /// Applies a phone picked from a contact (which may already carry a prefix in
  /// any of several shapes) to the prefix selector + local field.
  void _applyContactPhone(String raw) {
    var value = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    final split = splitStoredPhone(value);
    _phoneDialCode = split.dialCode;
    _phoneController.text = split.local;
  }

  /// Spec 009 §2.3: requests contacts permission, opens the device picker, and
  /// autofills the supplier name, phone and email from the chosen contact. When
  /// the contact has more than one phone or email, a selection sheet asks which
  /// to use. The user can still edit every field afterwards before saving.
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

  /// Returns the single value, the user-picked one when there are several, or
  /// null when the contact has none / the user dismisses the chooser.
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
              // §3 reorder: the category comes first (read-only for system /
              // pantry, editable for user categories), then the supplier name,
              // then the preferred channel, with the contact picker last.
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
                const SizedBox(height: 16),
                // Spec 008 §2.3: the concrete supplier name ("Peixos Samba"),
                // free text — but not for the Rebost pantry, which has no
                // supplier behind it.
                FieldLabel(
                  label: l10n.supplierNameLabel,
                  child: AppTextField(
                    controller: _supplierNameController,
                    hintText: l10n.supplierNameHint,
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                // Fixes round 2 §2.4: pair each preferred-channel option with
                // its address on the same row, so the link between a channel
                // and the address it sends to is immediate. Both addresses
                // stay stored and editable (Fixes §2.1); the non-selected rows
                // read as visually secondary. §3: WhatsApp / Email can only be
                // selected once their address is valid; the phone carries an
                // international prefix selector. Compartir / Cap need no address.
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
                // §3: the contact picker lives at the bottom, below the form it
                // fills (name + phone + email).
                SecondaryButton(
                  label: l10n.pickFromContactsAction,
                  icon: Icons.contacts_outlined,
                  onPressed: busy ? null : _pickFromContacts,
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

/// Inline validation caption for a channel row (§3), left-indented to sit under
/// the address field rather than the selector (the selector column is 70 px:
/// 62 px box + 8 px gap).
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
