import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/single_choice_sheet.dart';

/// One selectable international dialling prefix (Spec 009 Fixes §3).
class PhoneCountry {
  const PhoneCountry(this.iso, this.name, this.dialCode);

  /// ISO 3166-1 alpha-2 code, used to derive the device-locale default.
  final String iso;

  /// Human-readable country name shown in the picker.
  final String name;

  /// E.164 dialling prefix, e.g. `+34`.
  final String dialCode;
}

/// A deliberately short, hand-curated list rather than a full country database
/// (Spec 009 Fixes §3, lean-first): the app's users are Catalan/Spanish, so the
/// near markets and the common diaspora destinations cover the realistic cases
/// without pulling in a dependency. Ordered roughly by likelihood. The default
/// is Spain (+34) unless the device locale points elsewhere.
const List<PhoneCountry> phoneCountries = [
  PhoneCountry('ES', 'Espanya / España / Spain', '+34'),
  PhoneCountry('FR', 'França / Francia / France', '+33'),
  PhoneCountry('PT', 'Portugal', '+351'),
  PhoneCountry('IT', 'Itàlia / Italia / Italy', '+39'),
  PhoneCountry('DE', 'Alemanya / Alemania / Germany', '+49'),
  PhoneCountry('GB', 'Regne Unit / Reino Unido / UK', '+44'),
  PhoneCountry('IE', 'Irlanda / Ireland', '+353'),
  PhoneCountry('NL', 'Països Baixos / Países Bajos / Netherlands', '+31'),
  PhoneCountry('BE', 'Bèlgica / Bélgica / Belgium', '+32'),
  PhoneCountry('CH', 'Suïssa / Suiza / Switzerland', '+41'),
  PhoneCountry('AD', 'Andorra', '+376'),
  PhoneCountry('MA', 'Marroc / Marruecos / Morocco', '+212'),
  PhoneCountry('US', 'EUA / EE. UU. / USA', '+1'),
];

const PhoneCountry _fallbackCountry = PhoneCountry('ES', 'Espanya', '+34');

/// The dial code to preselect for a fresh field: the device locale's country
/// when it is one we list, otherwise Spain (+34) per §3.
String defaultPhoneDialCode() {
  final country = ui.PlatformDispatcher.instance.locale.countryCode;
  if (country != null) {
    for (final c in phoneCountries) {
      if (c.iso == country) return c.dialCode;
    }
  }
  return _fallbackCountry.dialCode;
}

/// Splits a stored E.164-ish phone (`+34600123456`) into its dial code and the
/// local part for editing. Matches the **longest** known prefix so `+351…`
/// wins over `+3…` style ambiguity. A value with no recognised prefix keeps the
/// default dial code and treats the whole string as the local part, so legacy
/// numbers typed before this field existed still load for editing.
({String dialCode, String local}) splitStoredPhone(String? stored) {
  final value = (stored ?? '').trim();
  if (value.isEmpty) {
    return (dialCode: defaultPhoneDialCode(), local: '');
  }
  PhoneCountry? best;
  for (final c in phoneCountries) {
    if (value.startsWith(c.dialCode)) {
      if (best == null || c.dialCode.length > best.dialCode.length) best = c;
    }
  }
  if (best != null) {
    return (
      dialCode: best.dialCode,
      local: value.substring(best.dialCode.length).trim(),
    );
  }
  return (dialCode: defaultPhoneDialCode(), local: value);
}

/// The digits of a local phone part, with spaces, dashes and parentheses
/// stripped. Used both to validate and to compose the stored value.
String _localDigits(String local) =>
    local.replaceAll(RegExp(r'[^0-9]'), '');

/// Whether [local] is a plausible subscriber number for storage: 6–15 digits
/// once separators are stripped (E.164 caps the full number, including the
/// country code, at 15). Deliberately lenient — exact per-country lengths would
/// need a phone-metadata library, out of scope for this lean fix (§3).
bool isValidLocalPhone(String local) {
  final digits = _localDigits(local);
  return digits.length >= 6 && digits.length <= 15;
}

/// Composes the value persisted to `phone_address`: dial code + local digits
/// (`+34600123456`), or empty string when the local part is blank so an unset
/// phone stays null upstream.
String composeStoredPhone(String dialCode, String local) {
  final digits = _localDigits(local);
  if (digits.isEmpty) return '';
  return '$dialCode$digits';
}

/// Phone input with an international dial-code prefix (Spec 009 Fixes §3): a
/// tappable prefix chip opens a country picker; the trailing field holds the
/// local number. The parent owns both the [dialCode] and the [controller] so it
/// can compose the stored E.164 value and run the channel validation.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.dialCode,
    required this.controller,
    required this.onDialCodeChanged,
    this.hintText,
    this.enabled = true,
    this.onChanged,
  });

  final String dialCode;
  final TextEditingController controller;
  final ValueChanged<String> onDialCodeChanged;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  Future<void> _pickCountry(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showSingleChoiceSheet<String>(
      context: context,
      title: l10n.phoneCountryPickerTitle,
      options: [
        for (final c in phoneCountries)
          SingleChoiceOption(
            value: c.dialCode,
            label: '${c.name}  (${c.dialCode})',
          ),
      ],
      selectedValue: dialCode,
      onSelected: onDialCodeChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DialCodeChip(
          dialCode: dialCode,
          onTap: enabled ? () => _pickCountry(context) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppTextField(
            controller: controller,
            hintText: hintText,
            keyboardType: TextInputType.phone,
            textCapitalization: TextCapitalization.none,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// The tappable prefix box, styled to match [AppTextField] so the prefix and
/// the number read as one control.
class _DialCodeChip extends StatelessWidget {
  const _DialCodeChip({required this.dialCode, required this.onTap});

  final String dialCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialCode, style: AppTypography.body),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
