import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// International dial-code prefix handling for the supplier phone (Spec 009
/// §3.2). The hand-curated short country list of the first fixes round is
/// replaced here by the `intl_phone_field` package, which carries the full
/// worldwide set of dial codes and a searchable country picker — the standard
/// mobile-app treatment. The default country follows the device locale.
///
/// The screen still owns the dial code and the local-number controller and
/// composes / validates the stored E.164 value, so the helpers below convert
/// between the package's country data and the `+NN` strings the rest of the
/// code already speaks.

const String _fallbackIso = 'ES';
const String _fallbackDialCode = '+34';

/// The package's country record for an ISO alpha-2 code, or Spain as the
/// fallback so callers always get a concrete country.
Country _countryForIso(String iso) => countries.firstWhere(
  (c) => c.code == iso,
  orElse: () =>
      countries.firstWhere((c) => c.code == _fallbackIso),
);

/// The device locale's country if `intl_phone_field` knows it, else Spain —
/// used as the default selection for a fresh field (§3.2).
String defaultPhoneCountryIso() {
  final code = ui.PlatformDispatcher.instance.locale.countryCode;
  if (code != null && countries.any((c) => c.code == code)) return code;
  return _fallbackIso;
}

/// The dial code (`+34`) to preselect for a fresh field: the device locale's
/// country when known, otherwise Spain.
String defaultPhoneDialCode() => '+${_countryForIso(defaultPhoneCountryIso()).dialCode}';

/// ISO alpha-2 code for a stored `+NN` dial code, for
/// [IntlPhoneField.initialCountryCode]. The longest matching dial code wins
/// (`+351` over `+3…`); shared codes (e.g. `+1`) resolve to the first listed
/// country, which is adequate for the local part round-trip.
String isoForDialCode(String dialCode) {
  final digits = dialCode.startsWith('+') ? dialCode.substring(1) : dialCode;
  Country? best;
  for (final c in countries) {
    if (digits == c.dialCode) {
      if (best == null || c.dialCode.length > best.dialCode.length) best = c;
    }
  }
  return best?.code ?? defaultPhoneCountryIso();
}

/// Splits a stored E.164-ish phone (`+34600123456`) into its dial code and the
/// local part for editing. Matches the **longest** known prefix so `+351…`
/// wins over `+3…` ambiguity. A value with no recognised prefix keeps the
/// default dial code and treats the whole string as the local part, so legacy
/// numbers typed before this field existed still load for editing.
({String dialCode, String local}) splitStoredPhone(String? stored) {
  final value = (stored ?? '').trim();
  if (value.isEmpty) {
    return (dialCode: defaultPhoneDialCode(), local: '');
  }
  if (value.startsWith('+')) {
    final rest = value.substring(1);
    Country? best;
    for (final c in countries) {
      if (rest.startsWith(c.dialCode)) {
        if (best == null || c.dialCode.length > best.dialCode.length) best = c;
      }
    }
    if (best != null) {
      return (
        dialCode: '+${best.dialCode}',
        local: rest.substring(best.dialCode.length).trim(),
      );
    }
  }
  return (dialCode: defaultPhoneDialCode(), local: value);
}

/// The digits of a local phone part, with spaces, dashes and parentheses
/// stripped. Used both to validate and to compose the stored value.
String _localDigits(String local) => local.replaceAll(RegExp(r'[^0-9]'), '');

/// Whether [local] is a plausible subscriber number for storage: 6–15 digits
/// once separators are stripped (E.164 caps the full number, including the
/// country code, at 15). Deliberately lenient — the package's own per-country
/// length check is disabled so this stays the single source of validity (§3.2).
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
  final prefix = dialCode.isEmpty ? _fallbackDialCode : dialCode;
  return '$prefix$digits';
}

/// Phone input with a worldwide international dial-code prefix (Spec 009 §3.2),
/// backed by `intl_phone_field`: the leading flag button opens a searchable
/// country picker; the trailing field holds the local number. The parent owns
/// both the [dialCode] and the [controller] so it can compose the stored E.164
/// value and run the channel validation; [onDialCodeChanged] fires when the
/// user picks a different country, [onChanged] when the local digits change.
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

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      // The selected country lives in the widget's own state and is seeded from
      // initialCountryCode only at init; keying on the dial code rebuilds it
      // when the parent reseeds the prefix externally (a contact pick), so the
      // flag stays in sync with the stored number.
      key: ValueKey(dialCode),
      controller: controller,
      enabled: enabled,
      initialCountryCode: isoForDialCode(dialCode),
      languageCode: Localizations.localeOf(context).languageCode,
      // The screen keeps its own 6–15 digit rule (isValidLocalPhone) as the
      // single source of validity; disabling the package's per-country length
      // check avoids a second, conflicting error and its character counter.
      disableLengthCheck: true,
      showCountryFlag: true,
      dropdownIconPosition: IconPosition.trailing,
      style: AppTypography.body,
      dropdownTextStyle: AppTypography.body,
      cursorColor: AppColors.accent,
      flagsButtonPadding: const EdgeInsets.only(left: 8),
      decoration: _decoration(hintText),
      onChanged: (phone) => onChanged?.call(phone.number),
      onCountryChanged: (country) => onDialCodeChanged('+${country.dialCode}'),
    );
  }

  /// Matches [AppTextField]'s decoration so the prefix + number read as one
  /// control consistent with the rest of the form.
  InputDecoration _decoration(String? hintText) => InputDecoration(
    hintText: hintText,
    hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: _outline(AppColors.border),
    enabledBorder: _outline(AppColors.border),
    focusedBorder: _outline(AppColors.accentSecondary),
    isDense: true,
  );

  OutlineInputBorder _outline(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}
