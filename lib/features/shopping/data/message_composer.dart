/// Composes the universal-text supplier message (Specification 005 §2.4,
/// amended by Fixes §2.5 and Fixes round 2 §2.1–§2.2).
///
/// Plain text, no Markdown or platform styling: an optional greeting line, an
/// optional needed-by line, the items one per line, then the signature
/// separated by a blank line. The caller resolves the localised pieces (the
/// greeting, the needed-by sentence, the `de` connector, unit names, the
/// signature) and passes them in, so this stays free of BuildContext and is
/// unit-testable.
///
/// Fixes §2.5: the leading line used to carry the event title and date, which
/// leak private information to the supplier. It now carries only the needed-by
/// sentence ("Per al dia 5 de juny") — or nothing, when the user left the
/// needed-by date empty.
///
/// Fixes round 2 §2.1: a configurable greeting now heads the message. §2.2: each
/// item line carries its preparation note when present.
library;

/// Builds the message body. [greeting] heads the message on its own line
/// followed by a blank line, and is omitted (with that blank) when empty;
/// [leadingLine] is e.g. "Per al dia 5 de juny" and is likewise omitted with
/// its trailing blank when empty; [itemLines] are the pre-formatted item
/// strings; [signature] is appended after a blank line when non-empty.
String composeMessageBody({
  required String greeting,
  required String leadingLine,
  required List<String> itemLines,
  required String signature,
}) {
  final trimmedGreeting = greeting.trim();
  final trimmedLeading = leadingLine.trim();
  final lines = <String>[
    if (trimmedGreeting.isNotEmpty) ...[trimmedGreeting, ''],
    if (trimmedLeading.isNotEmpty) ...[trimmedLeading, ''],
    ...itemLines,
  ];
  final trimmedSignature = signature.trim();
  if (trimmedSignature.isNotEmpty) {
    lines
      ..add('')
      ..add(trimmedSignature);
  }
  return lines.join('\n');
}

/// Formats one item line as `<quantity> <unit> <connector> <ingredient name>`,
/// e.g. "250 g de tonyina". The unit collapses when unknown so the line never
/// shows a dangling space, and the [connector] (the localised Catalan "de") is
/// likewise dropped when empty.
///
/// Fixes round 1 §2.2: when [prepNote] is non-empty its preparation clause is
/// appended after a comma — "250 g de tonyina, tallada a daus petits".
///
/// Spec 006 §2.3: when there is no unit (a countable item like eggs or lemons)
/// the connector is dropped along with it, so the line reads "3 ous" — the
/// natural Catalan — rather than "3 de ous". The prep_note clause is unaffected
/// and still appears after a comma whenever [prepNote] is non-empty, with or
/// without a unit. (Fixes §2.3 reuses the no-unit path: the caller passes a null
/// [unit] for a unit flagged `omit_in_display`, so "3 unitats de ous" becomes
/// "3 ous".)
///
/// Fixes §2.4: when [elideConnector] is true the connector goes through the
/// Catalan elision rule "de" → "d'" before a vowel or a silent "h" ("200 g
/// d'oli"). The flag is Catalan-specific; callers pass false for other
/// languages.
///
/// Fixes round 2 §2.3: the catalog stores ingredient names and prep notes in
/// Title Case ("Anxoves", "En oli d'oliva") for natural reading in catalog
/// screens, but mid-sentence that reads wrong in the message. The first
/// character of both the ingredient name and the prep note is lowercased here
/// so the line reads as natural Catalan prose ("80 g d'anxoves, en oli
/// d'oliva"); the rest of each string is preserved as-is.
String composeItemLine({
  required String quantity,
  required String? unit,
  required String connector,
  required String ingredientName,
  String? prepNote,
  bool elideConnector = false,
}) {
  final hasUnit = unit != null && unit.isNotEmpty;
  final measure = hasUnit ? '$quantity $unit' : quantity;
  final trimmedConnector = connector.trim();
  // Fixes round 2 §2.3: lowercase the initial so it reads as prose mid-line.
  final name = _firstCharToLowercase(ingredientName);
  // The connector ("de") only makes sense between a unit and the ingredient;
  // with no unit it is dropped so "3 ous" reads naturally (§2.3).
  final String base;
  if (!hasUnit || trimmedConnector.isEmpty) {
    base = '$measure $name';
  } else {
    base = '$measure '
        '${catalanConnector(trimmedConnector, name, elide: elideConnector)}';
  }
  final note = _firstCharToLowercase(prepNote?.trim() ?? '');
  return note.isEmpty ? base : '$base, $note';
}

/// Fixes round 2 §2.3 — lowercases only the first character of [text], leaving
/// the rest untouched so any internal proper nouns or acronyms keep their case.
/// Returns [text] unchanged when empty.
String _firstCharToLowercase(String text) {
  if (text.isEmpty) return text;
  return text[0].toLowerCase() + text.substring(1);
}

/// Fixes §2.4 — Catalan elision. Joins [connector] ("de") to [nextWord],
/// contracting "de" → "d'" with no trailing space before a vowel or a silent
/// "h" ("d'oli", "d'hortalisses") when [elide] is true; otherwise emits
/// `connector nextWord` verbatim ("de tonyina"). The contraction is
/// Catalan-specific, so non-Catalan callers pass `elide: false`. The simple
/// vowel-or-h test covers the vast majority of food names; the rare exceptions
/// (aspirated h, some loanwords) are left for if and when they appear.
String catalanConnector(
  String connector,
  String nextWord, {
  required bool elide,
}) {
  if (!elide) return '$connector $nextWord';
  final stripped = nextWord.trimLeft();
  if (stripped.isNotEmpty &&
      _catalanElisionInitials.contains(stripped[0].toLowerCase())) {
    return "d'$stripped";
  }
  return '$connector $nextWord';
}

/// Initial letters that trigger the "de" → "d'" elision in Catalan: the five
/// vowels (including accented forms) and the silent "h".
const Set<String> _catalanElisionInitials = {
  'a', 'e', 'i', 'o', 'u', 'h', //
  'à', 'á', 'è', 'é', 'í', 'ï', 'ò', 'ó', 'ú', 'ü',
};
