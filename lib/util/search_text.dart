/// Spec 011 §2.11.d — text normalisation for accent- and case-insensitive
/// search across the app.
///
/// [foldForSearch] lowercases its input and folds Latin diacritics to their
/// base letter, so "Sípia" matches "sip", "Síp", "SÍP", etc. Apply it to BOTH
/// sides of every search comparison (the haystack and the query) so the match
/// is symmetric. It covers the diacritics of the app's languages (Catalan,
/// Spanish, English) plus the broader Latin-1 / Latin Extended-A set; every
/// folded character is in the Unicode BMP and a single UTF-16 unit.
library;

/// The lowercase accented characters that fold to each base letter. Lowercasing
/// happens first, so only lowercase forms are listed here.
const Map<String, String> _foldGroups = {
  'a': 'àáâãäåāăąǎ',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'i': 'ìíîïĩīĭįı',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşš',
  't': 'ţťŧ',
  'u': 'ùúûüũūŭůűų',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

/// Multi-character folds (ligatures / sharp s).
const Map<String, String> _multiFolds = {'æ': 'ae', 'œ': 'oe', 'ß': 'ss'};

final Map<String, String> _folds = _buildFolds();

Map<String, String> _buildFolds() {
  final map = <String, String>{..._multiFolds};
  _foldGroups.forEach((base, accented) {
    for (final ch in accented.split('')) {
      map[ch] = base;
    }
  });
  return map;
}

/// Normalises [input] for accent- and case-insensitive search.
String foldForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_folds[ch] ?? ch);
  }
  return buffer.toString();
}
