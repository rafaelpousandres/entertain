import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 033 §A — onboarding demo dataset RPCs (server-side functions
/// `seed_demo` / `clear_demo_data`, both SECURITY DEFINER and scoped to the
/// caller's group).
class DemoRepository {
  DemoRepository(this._client);

  final SupabaseClient _client;

  /// Seed the caller's (brand-new) group with the demo dataset in [locale].
  /// One-shot and guarded server-side; safe to call more than once.
  Future<void> seedDemo(String locale) async {
    await _client.rpc('seed_demo', params: {'p_locale': locale});
  }

  /// Whether the group still holds any demo data — drives the banner.
  Future<bool> hasDemoData(String groupId) async {
    final rows = await _client
        .from('events')
        .select('id')
        .eq('group_id', groupId)
        .eq('is_demo', true)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Delete exactly the demo data of the caller's group, preserving anything
  /// the user created. Returns the user-owned blob paths to purge from Storage
  /// (the shared read-only `demo/` assets are deliberately left in place).
  Future<List<({String bucket, String path})>> clearDemoData() async {
    final rows = await _client.rpc('clear_demo_data') as List;
    return rows
        .map((r) => (
              bucket: (r as Map)['bucket'] as String,
              path: r['path'] as String,
            ))
        .toList();
  }
}
