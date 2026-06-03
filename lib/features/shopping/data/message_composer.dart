/// Composes the universal-text supplier message (Specification 005 §2.4).
///
/// Plain text, no Markdown or platform styling: a brief identifying line,
/// the items one per line as `<quantity> <unit> <ingredient name>`, then the
/// signature separated by a blank line. The caller resolves the localised
/// pieces (date text, unit names, signature) and passes them in, so this
/// stays free of BuildContext and is unit-testable.
library;

/// Builds the message body. [identifyingLine] is e.g. "Sopar · 14 de juny";
/// [itemLines] are the pre-formatted item strings; [signature] is appended
/// after a blank line when non-empty.
String composeMessageBody({
  required String identifyingLine,
  required List<String> itemLines,
  required String signature,
}) {
  final lines = <String>[identifyingLine, '', ...itemLines];
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
