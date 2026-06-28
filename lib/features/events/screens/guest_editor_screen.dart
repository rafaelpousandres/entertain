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
import '../../../ui/segmented_choice.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../../util/contact_picker.dart';
import '../../../util/email_validator.dart';
import '../../catalog/data/diet.dart';
import '../../catalog/widgets/diet_choice.dart';
import '../../shopping/widgets/phone_field.dart';
import '../data/event_guest.dart';
import '../data/events_providers.dart';
import '../data/guest_invitation.dart';
import '../data/guest_state.dart';

/// Spec 023 §1.2/§1.4 — add or edit one guest. Mirrors the supplier editor:
/// name/phone/email form (reusing [PhoneField] + the shared contact picker) plus
/// the manual RSVP state. Saving with neither phone nor email is allowed — the
/// guest just can't be invited until one is added (§1.2).
class GuestEditorScreen extends ConsumerStatefulWidget {
  const GuestEditorScreen({super.key, required this.eventId, this.guest});

  final String eventId;

  /// The guest being edited; null when adding.
  final EventGuest? guest;

  bool get isEditing => guest != null;

  @override
  ConsumerState<GuestEditorScreen> createState() => _GuestEditorScreenState();
}

enum _OverflowAction { delete }

class _GuestEditorScreenState extends ConsumerState<GuestEditorScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _phoneDialCode = defaultPhoneDialCode();
  GuestState _state = GuestState.pendent;
  bool _vegetarian = false;
  bool _vegan = false;
  bool _glutenFree = false;
  bool _saving = false;
  bool _deleting = false;
  bool _dirty = false;
  String? _nameError;
  String? _phoneError;
  String? _emailError;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    final g = widget.guest;
    if (g != null) {
      _nameController.text = g.name;
      final phone = splitStoredPhone(g.phone);
      _phoneDialCode = phone.dialCode;
      _phoneController.text = phone.local;
      _emailController.text = g.email ?? '';
      _state = g.state;
      _vegetarian = g.dietVegetarian;
      _vegan = g.dietVegan;
      _glutenFree = g.dietGlutenFree;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    final localPhone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final nameEmpty = name.isEmpty;
    final phoneInvalid = localPhone.isNotEmpty && !isValidLocalPhone(localPhone);
    final emailInvalid = email.isNotEmpty && !isValidEmail(email);
    if (nameEmpty || phoneInvalid || emailInvalid) {
      setState(() {
        _nameError = nameEmpty ? l10n.guestNameRequired : null;
        _phoneError = phoneInvalid ? l10n.supplierPhoneInvalid : null;
        _emailError = emailInvalid ? l10n.supplierEmailInvalid : null;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _saving = true;
    });
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final phone = composeStoredPhone(_phoneDialCode, _phoneController.text);
      final phoneValue = phone.isEmpty ? null : phone;
      final emailValue = email.isEmpty ? null : email;
      if (widget.isEditing) {
        await repo.updateEventGuest(
          widget.guest!.id,
          name: name,
          phone: phoneValue,
          email: emailValue,
          state: _state,
          dietVegetarian: _vegetarian,
          dietVegan: _vegan,
          dietGlutenFree: _glutenFree,
        );
      } else {
        await repo.addEventGuest(
          widget.eventId,
          name: name,
          phone: phoneValue,
          email: emailValue,
          state: _state,
          dietVegetarian: _vegetarian,
          dietVegan: _vegan,
          dietGlutenFree: _glutenFree,
        );
      }
      ref.invalidate(eventGuestsProvider(widget.eventId));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.guestSaveError)));
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.guestDeleteConfirmTitle, style: AppTypography.sectionTitle),
        content: Text(
          l10n.guestDeleteConfirmBody,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancelAction,
              style: AppTypography.button.copyWith(color: AppColors.textSecondary),
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
    setState(() => _deleting = true);
    try {
      await ref.read(eventsRepositoryProvider).deleteEventGuest(widget.guest!.id);
      ref.invalidate(eventGuestsProvider(widget.eventId));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.guestSaveError)));
    }
  }

  /// Reuses the supplier contact-pick flow: permission → device picker →
  /// autofill name + (choice sheet for multiple) phone/email.
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
    final fields = guestFieldsFromContact(contact);
    if (fields.name != null && fields.name!.isNotEmpty) {
      _nameController.text = fields.name!;
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

  void _applyContactPhone(String raw) {
    var value = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    final split = splitStoredPhone(value);
    _phoneDialCode = split.dialCode;
    _phoneController.text = split.local;
  }

  Future<String?> _chooseContactValue(List<String> options, String title) async {
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first;
    String? chosen;
    await showSingleChoiceSheet<String>(
      context: context,
      title: title,
      options: [for (final o in options) SingleChoiceOption(value: o, label: o)],
      selectedValue: null,
      onSelected: (v) => chosen = v,
    );
    return chosen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EditScaffold(
      title: widget.isEditing ? l10n.guestEditorEditTitle : l10n.guestEditorNewTitle,
      hasUnsavedChanges: _dirty,
      busy: _busy,
      onSave: _busy ? null : _save,
      trailingActions: [
        if (widget.isEditing)
          PopupMenuButton<_OverflowAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreActionsLabel,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  l10n.guestDeleteAction,
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          FieldLabel(
            label: l10n.guestNameLabel,
            child: AppTextField(
              controller: _nameController,
              hintText: l10n.guestNameHint,
              onChanged: (_) {
                _markDirty();
                if (_nameError != null && _nameController.text.trim().isNotEmpty) {
                  setState(() => _nameError = null);
                }
              },
            ),
          ),
          if (_nameError != null) _FieldError(message: _nameError!),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.guestPhoneLabel,
            child: PhoneField(
              dialCode: _phoneDialCode,
              controller: _phoneController,
              hintText: l10n.guestPhoneHint,
              onDialCodeChanged: (code) {
                setState(() => _phoneDialCode = code);
                _markDirty();
              },
              onChanged: (_) {
                _markDirty();
                if (_phoneError != null) setState(() => _phoneError = null);
              },
            ),
          ),
          if (_phoneError != null) _FieldError(message: _phoneError!),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.guestEmailLabel,
            child: AppTextField(
              controller: _emailController,
              hintText: l10n.guestEmailHint,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              onChanged: (value) {
                _markDirty();
                if (_emailError != null && isValidEmail(value)) {
                  setState(() => _emailError = null);
                }
              },
            ),
          ),
          if (_emailError != null) _FieldError(message: _emailError!),
          const SizedBox(height: 24),
          Text(
            l10n.guestStateFieldLabel,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SegmentedChoice<GuestState>(
            value: _state,
            onChanged: (v) => setState(() {
              _state = v;
              _dirty = true;
            }),
            options: [
              for (final s in guestStateOrder)
                SegmentedChoiceOption(s, guestStateLabel(l10n, s)),
            ],
          ),
          const SizedBox(height: 24),
          // Spec 029 (manual scope) — the host sets the guest's restrictions with
          // the same VGT/VGN/SG pills the catalog uses, here pressable: tap to
          // toggle (on = badge colour, off = dimmed). No restriction = none
          // selected (the old "Cap" is gone). Vegetarian and vegan are mutually
          // exclusive — selecting one clears the other; gluten-free is independent.
          // No "unknown" state (unlike ingredients).
          Text(
            l10n.guestDietSectionLabel,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DietChoicePill(
                label: l10n.dietLevelVegetarian,
                badge: DietBadge.vegetarian,
                selected: _vegetarian,
                onTap: () => setState(() {
                  _vegetarian = !_vegetarian;
                  if (_vegetarian) _vegan = false; // veg ⊥ vegan
                  _dirty = true;
                }),
              ),
              DietChoicePill(
                label: l10n.dietLevelVegan,
                badge: DietBadge.vegan,
                selected: _vegan,
                onTap: () => setState(() {
                  _vegan = !_vegan;
                  if (_vegan) _vegetarian = false; // veg ⊥ vegan
                  _dirty = true;
                }),
              ),
              DietChoicePill(
                label: l10n.guestGlutenFreeLabel,
                badge: DietBadge.glutenFree,
                selected: _glutenFree,
                onTap: () => setState(() {
                  _glutenFree = !_glutenFree;
                  _dirty = true;
                }),
              ),
            ],
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        message,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}
