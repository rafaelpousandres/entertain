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
/// Fixes round 2 §2.2: when [prepNote] is non-empty its preparation clause is
/// appended after a comma — "250 g de tonyina, tallada a daus petits". The note
/// is rendered exactly as the user entered it (no case change), and no Catalan
/// elision is applied to the connector for this iteration ("de oli", not
/// "d'oli").
///
/// Spec 006 §2.3: when there is no unit (a countable item like eggs or lemons)
/// the connector is dropped along with it, so the line reads "3 ous" — the
/// natural Catalan — rather than "3 de ous". The prep_note clause is unaffected
/// and still appears after a comma whenever [prepNote] is non-empty, with or
/// without a unit.
String composeItemLine({
  required String quantity,
  required String? unit,
  required String connector,
  required String ingredientName,
  String? prepNote,
}) {
  final hasUnit = unit != null && unit.isNotEmpty;
  final measure = hasUnit ? '$quantity $unit' : quantity;
  final trimmedConnector = connector.trim();
  // The connector ("de") only makes sense between a unit and the ingredient;
  // with no unit it is dropped so "3 ous" reads naturally (§2.3).
  final connectorPart = (!hasUnit || trimmedConnector.isEmpty)
      ? ''
      : '$trimmedConnector ';
  final base = '$measure $connectorPart$ingredientName';
  final note = prepNote?.trim() ?? '';
  return note.isEmpty ? base : '$base, $note';
}
