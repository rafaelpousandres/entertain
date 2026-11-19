import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/translations_query.dart';
import 'hint.dart';
import 'hint_selection.dart';

/// Spec 026 A.4 — reads the DB-backed hint set, localizing each hint's text via
/// the shared `translations` model (same merge as catalog names): the app-locale
/// text, falling back to Catalan. Read-only (RLS grants `select` only).
class HintsRepository {
  HintsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Hint>> listHints(String localeCode) async {
    final rows = await _client.from('hints').select(Hint.selectColumns);
    final texts = await fetchTranslationTexts(
      _client,
      entityType: 'hint',
      entityIds: [
        for (final r in rows as List)
          (r as Map<String, dynamic>)['id'] as String,
      ],
      locales: {localeCode, 'ca'},
      field: 'text',
    );
    final local = texts[localeCode]!;
    final ca = texts['ca']!;

    final hints = <Hint>[];
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final id = m['id'] as String;
      final text = mergeHintText(local, ca, id);
      if (text.isEmpty) continue; // a hint with no translation is not shown
      hints.add(
        Hint(
          id: id,
          key: m['key'] as String,
          kind: HintKind.parse(m['kind'] as String),
          text: text,
        ),
      );
    }
    return hints;
  }
}
