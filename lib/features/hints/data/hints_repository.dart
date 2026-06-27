import 'package:supabase_flutter/supabase_flutter.dart';

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
    final local = await _hintText(localeCode);
    final ca = localeCode == 'ca' ? local : await _hintText('ca');

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

  /// entity_id → hint text for a locale (field `text`).
  Future<Map<String, String>> _hintText(String localeCode) async {
    final rows = await _client
        .from('translations')
        .select('entity_id, text')
        .eq('entity_type', 'hint')
        .eq('locale', localeCode)
        .eq('field', 'text');
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['entity_id'] as String:
            r['text'] as String,
    };
  }
}
