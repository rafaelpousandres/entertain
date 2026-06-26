/// Spec 025 Part A — pure helpers for multilingual catalog names.
///
/// Names are stored in the `translations` table (reused); the repository merges
/// the app-locale and English maps into each model. These helpers are the pure,
/// testable bits: pick the localized name, and build the bilingual photo-search
/// term (D2).
library;

/// The display name: the translated name for the app locale when present,
/// otherwise the row's stored (original-locale) name. Used by the repository
/// when mapping rows so every screen keeps reading `entity.name`.
String localizedName(String? translated, String rowName) {
  final t = translated?.trim();
  return (t == null || t.isEmpty) ? rowName : t;
}

/// D2 — the Pexels search term: the entity name in the user's locale plus its
/// English name (the quality bridge for Pexels), deduped when identical or when
/// English is missing.
String photoSearchTerm(String localName, String? englishName) {
  final local = localName.trim();
  final en = englishName?.trim() ?? '';
  if (en.isEmpty || en.toLowerCase() == local.toLowerCase()) return local;
  if (local.isEmpty) return en;
  return '$local $en';
}
