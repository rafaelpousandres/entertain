/// Composes the universal-text supplier message (Specification 005 §2.4,
/// amended by Fixes §2.5).
///
/// Plain text, no Markdown or platform styling: an optional leading line, the
/// items one per line as `<quantity> <unit> <ingredient name>`, then the
/// signature separated by a blank line. The caller resolves the localised
/// pieces (the needed-by sentence, unit names, signature) and passes them in,
/// so this stays free of BuildContext and is unit-testable.
///
/// Fixes §2.5: the leading line used to carry the event title and date, which
/// leak private information to the supplier. It now carries only the needed-by
/// sentence ("Per al dia 5 de juny") — or nothing, when the user left the
/// needed-by date empty.
library;

/// Builds the message body. [leadingLine] is e.g. "Per al dia 5 de juny" and
/// is omitted (with its trailing blank) when empty; [itemLines] are the
/// pre-formatted item strings; [signature] is appended after a blank line when
/// non-empty.
String composeMessageBody({
  required String leadingLine,
  required List<String> itemLines,
  required String signature,
}) {
  final trimmedLeading = leadingLine.trim();
  final lines = <String>[
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

/// Formats one item line: `<quantity> <unit> <ingredient name>`, collapsing
/// the unit when it is unknown so the line never shows a dangling space.
String composeItemLine({
  required String quantity,
  required String? unit,
  required String ingredientName,
}) {
  final measure = (unit == null || unit.isEmpty)
      ? quantity
      : '$quantity $unit';
  return '$measure $ingredientName';
}
