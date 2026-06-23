import 'package:supabase_flutter/supabase_flutter.dart';

/// Data-access for the `suggestions` table (Specification 021 Part A).
///
/// A lightweight feedback channel: the client inserts a free-text suggestion
/// directly under RLS (no Edge Function), and reads a plain count of the
/// group's suggestions for the "N suggeriments enviats" indicator. RLS scopes
/// every row to the caller's group via `is_group_member`, so the group filter
/// here is only for the counter (insert membership is enforced by the policy).
class SuggestionsRepository {
  SuggestionsRepository(this._client);

  final SupabaseClient _client;

  /// Persists one suggestion. [appVersion] is captured from the client
  /// (package_info) so the later dump carries the version it came from;
  /// [userId] may be null for an anonymous session.
  Future<void> create({
    required String groupId,
    required String? userId,
    required String? appVersion,
    required String text,
  }) async {
    await _client.from('suggestions').insert({
      'group_id': groupId,
      'user_id': userId,
      'app_version': appVersion,
      'text': text,
    });
  }

  /// How many suggestions the caller's group has sent. Uses an exact count
  /// with no rows transferred (`head` via the empty select); RLS already
  /// restricts the rows to the group, and the explicit filter mirrors the
  /// spec's `where group_id = ...`.
  Future<int> countForGroup(String groupId) async {
    final res = await _client
        .from('suggestions')
        .select('id')
        .eq('group_id', groupId)
        .count(CountOption.exact);
    return res.count;
  }
}
