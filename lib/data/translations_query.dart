/// The single place the app reads the `translations` table.
///
/// Every read is restricted to an explicit set of entity ids and sent in
/// blocks. An unfiltered read ("all the name translations of a type") returns
/// whatever the server lets the caller see, and the API silently cuts a
/// response at 1000 rows: in November 2026 that left recent accounts with an
/// untranslated catalog. Row-level security is the security boundary, not the
/// query's filter — the client always asks only for its own entities.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Ids per request. With at most two locales per call a block returns at most
/// 200 rows — far below the API's 1000-row cap — and keeps the URL short.
const translationIdBlockSize = 100;

/// Splits [ids] into de-duplicated blocks of at most [size].
List<List<String>> translationIdBlocks(
  Iterable<String> ids, {
  int size = translationIdBlockSize,
}) {
  final unique = ids.toSet().toList();
  return [
    for (var i = 0; i < unique.length; i += size)
      unique.sublist(i, i + size > unique.length ? unique.length : i + size),
  ];
}

/// locale → (entity_id → text) for the given [entityIds], [locales] and
/// [field] of one [entityType]. Returns empty maps when there are no ids
/// (no request is made).
Future<Map<String, Map<String, String>>> fetchTranslationTexts(
  SupabaseClient client, {
  required String entityType,
  required Iterable<String> entityIds,
  required Set<String> locales,
  required String field,
}) async {
  final result = {for (final l in locales) l: <String, String>{}};
  final blocks = translationIdBlocks(entityIds);
  if (blocks.isEmpty || locales.isEmpty) return result;

  final responses = await Future.wait([
    for (final block in blocks)
      client
          .from('translations')
          .select('entity_id, locale, text')
          .eq('entity_type', entityType)
          .eq('field', field)
          .inFilter('locale', locales.toList())
          .inFilter('entity_id', block),
  ]);
  for (final rows in responses) {
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      result[row['locale'] as String]?[row['entity_id'] as String] =
          row['text'] as String;
    }
  }
  return result;
}
