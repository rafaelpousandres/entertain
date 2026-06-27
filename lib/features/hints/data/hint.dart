/// Spec 026 Part A — a discoverability hint shown on app entry.
///
/// Content is DB-backed: the row lives in `hints` and the localized [text] in
/// `translations` (entity_type `hint`, field `text`), so hints can be edited,
/// added or removed directly in the database without shipping a new build.
library;

enum HintKind {
  /// The greeting shown the very first time the app opens.
  welcome,

  /// A rotating tip, chosen at random on later opens.
  tip;

  static HintKind parse(String wire) =>
      wire == 'welcome' ? HintKind.welcome : HintKind.tip;
}

class Hint {
  const Hint({
    required this.id,
    required this.key,
    required this.kind,
    required this.text,
  });

  /// Columns read from `hints`; the [text] is merged in from `translations`.
  static const String selectColumns = 'id, key, kind';

  final String id;

  /// Stable identifier (e.g. `welcome`, `ai_recipe`). Not shown to the user.
  final String key;

  final HintKind kind;

  /// The hint body in the app locale (falls back to Catalan).
  final String text;
}
