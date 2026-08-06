/// Spec 019 §A — client-side quota model + the shared server read path.
///
/// The quota is enforced server-side (Edge Functions + `quota_usage` with the
/// atomic `consume_quota` RPC). The client holds NO limit values and does NOT
/// compute periods: `get_quota_status` returns the effective (used, limit)
/// pair resolved by the single source of truth (`effective_quota_limit`:
/// group entitlement > `quota_defaults` row), computing the period itself.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// The quota key for stock photos (`quota_key` namespaces consumers so the URL
/// importer / AI features reuse the same tables later).
const String kStockPhotosQuotaKey = 'stock_photos';

/// A group's usage for the current period, as resolved by the server.
class QuotaStatus {
  const QuotaStatus({required this.used, required this.limit});

  final int used;
  final int limit;

  /// Uses still available this month (never negative).
  int get remaining => used >= limit ? 0 : limit - used;

  /// Whether the cap is reached (the paywall seam).
  bool get isExhausted => used >= limit;
}

/// Shared read path for every quota consumer: one `get_quota_status` call,
/// (used, limit) already resolved server-side. Throws on a missing row (caller
/// is not a group member) or a NULL limit (quota_defaults seed row deleted) —
/// fail closed and loudly, never guess a number the server didn't confirm.
Future<QuotaStatus> fetchQuotaStatus(
  SupabaseClient client, {
  required String groupId,
  required String quotaKey,
}) async {
  final rows =
      await client.rpc(
            'get_quota_status',
            params: {'p_group_id': groupId, 'p_quota_key': quotaKey},
          )
          as List<dynamic>;
  if (rows.isEmpty) {
    throw StateError('get_quota_status: no row (not a member of $groupId?)');
  }
  final row = (rows.first as Map).cast<String, dynamic>();
  final limit = row['quota_limit'] as num?;
  if (limit == null) {
    throw StateError('get_quota_status: no limit configured for $quotaKey');
  }
  return QuotaStatus(
    used: ((row['used'] as num?) ?? 0).toInt(),
    limit: limit.toInt(),
  );
}
