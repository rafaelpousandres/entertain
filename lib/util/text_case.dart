/// Spec 016 §5.2 — display-case helper.
///
/// Catalog item names (ingredients) are shown with a capital initial. Drinks
/// and prepared-dish lines should read the same way, so display surfaces run
/// their names through [capitalizeFirst]. This is the display counterpart of
/// the message composer's first-char-lowercase rule (which makes a name read as
/// prose mid-sentence). Only the first character is touched; the rest is left
/// as-is so internal proper nouns / acronyms keep their case.
library;

/// Uppercases the first character of [text], leaving the rest unchanged.
/// Returns [text] unchanged when empty.
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
