/// Shared email format check (Spec 009 §3; reused by Spec 023 guests).
///
/// RFC 5322-subset, the HTML5 `type=email` grammar: a local part of permitted
/// characters, an `@`, then one or more dot-separated labels. Kept in one place
/// so the supplier editor and the guest editor validate identically.
library;

final _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
);

bool isValidEmail(String value) => _emailRegExp.hasMatch(value.trim());
